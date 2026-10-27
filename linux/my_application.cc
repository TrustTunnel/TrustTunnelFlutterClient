#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

// Registered in my_application_activate; kept alive for the whole app lifetime.
static FlMethodChannel* g_exit_dialog_channel = nullptr;

// Shows the native exit confirmation dialog (GtkMessageDialog) and responds
// with true when the user chose Quit, false otherwise.
static void exit_dialog_method_call_cb(FlMethodChannel* /*channel*/,
                                       FlMethodCall* method_call,
                                       gpointer user_data) {
  const gchar* method = fl_method_call_get_name(method_call);
  if (g_strcmp0(method, "show") != 0) {
    fl_method_call_respond_not_implemented(method_call, nullptr);
    return;
  }

  GtkWindow* window = GTK_WINDOW(user_data);
  FlValue* args = fl_method_call_get_args(method_call);
  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    fl_method_call_respond_error(method_call, "bad-args", "Expected a map of arguments", nullptr, nullptr);
    return;
  }

  static const gchar* const kKeys[] = {
      "title",
      "message",
      "quitButtonText",
      "dontQuitButtonText",
  };
  const gchar* values[G_N_ELEMENTS(kKeys)] = {"", "", "", ""};
  for (size_t i = 0; i < G_N_ELEMENTS(kKeys); ++i) {
    FlValue* value = fl_value_lookup_string(args, kKeys[i]);
    if (value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_STRING) {
      values[i] = fl_value_get_string(value);
    }
  }
  const gchar* title = values[0];
  const gchar* message = values[1];
  const gchar* quit_text = values[2];
  const gchar* cancel_text = values[3];

  GtkWidget* dialog = gtk_message_dialog_new(window,
                                             GTK_DIALOG_MODAL,
                                             GTK_MESSAGE_QUESTION,
                                             GTK_BUTTONS_NONE,
                                             "%s", title);
  gtk_message_dialog_format_secondary_text(GTK_MESSAGE_DIALOG(dialog), "%s", message);

  gtk_dialog_add_button(GTK_DIALOG(dialog), cancel_text, GTK_RESPONSE_CANCEL);
  gtk_dialog_add_button(GTK_DIALOG(dialog), quit_text, GTK_RESPONSE_ACCEPT);

  // Runs a nested main loop: the rest of the UI stays alive while the dialog
  // is open, mirroring the Windows runner behavior.
  const gint response = gtk_dialog_run(GTK_DIALOG(dialog));
  gtk_widget_destroy(dialog);

  g_autoptr(FlValue) result = fl_value_new_bool(response == GTK_RESPONSE_ACCEPT);
  fl_method_call_respond_success(method_call, result, nullptr);
}

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Shows the window only after Flutter has rendered its first frame.
// This prevents pointer events from hitting an unlaid-out render tree while Dart
// is still initializing asynchronously before runApp().
static void view_first_frame_cb(FlView* /*view*/, gpointer user_data) {
  gtk_widget_show(GTK_WIDGET(user_data));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);

  // Single instance: if the window already exists (secondary launch or
  // re-activation), raise it instead of creating a new Flutter view.
  GList* windows = gtk_application_get_windows(GTK_APPLICATION(application));
  if (windows) {
    gtk_window_present(GTK_WINDOW(windows->data));
    return;
  }

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "vpn");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "vpn");
  }

  gtk_window_set_default_size(window, 1280, 720);
  // Keep the window realized but hidden until the first frame is rendered.
  gtk_widget_realize(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window automatically as soon as Flutter renders the first frame.
  // The signal is undocumented in the public headers and might be missing in
  // older engines: fall back to showing the window immediately, otherwise it
  // would never be shown at all.
  if (g_signal_lookup("first-frame", fl_view_get_type()) != 0) {
    g_signal_connect(view, "first-frame", G_CALLBACK(view_first_frame_cb), window);
  } else {
    g_warning("FlView has no \"first-frame\" signal: showing the window immediately");
    gtk_widget_show(GTK_WIDGET(window));
  }

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Exit confirmation dialog channel (lib/common/platform/linux_exit_dialog.dart).
  g_clear_object(&g_exit_dialog_channel);
  g_autoptr(FlPluginRegistrar) registrar = fl_plugin_registry_get_registrar_for_plugin(
      FL_PLUGIN_REGISTRY(view), "VpnPlugin");
  FlBinaryMessenger* messenger = fl_plugin_registrar_get_messenger(registrar);
  g_exit_dialog_channel = fl_method_channel_new(messenger,
                                                "trusttunnel/linux_exit_dialog",
                                                FL_METHOD_CODEC(fl_standard_method_codec_new()));
  fl_method_channel_set_method_call_handler(g_exit_dialog_channel,
                                            exit_dialog_method_call_cb,
                                            g_object_ref(window),
                                            g_object_unref);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  // Secondary instance: returning FALSE makes GApplication forward the
  // arguments to the primary instance over D-Bus (GApplication::command-line /
  // ::open — picked up by the gtk plugin and forwarded to app_links) and
  // terminate this process. g_application_activate() on a remote instance is
  // forwarded as well, so the primary window is raised.
  if (g_application_get_is_remote(application)) {
    g_application_activate(application);
    *exit_status = 0;
    return FALSE;
  }

  // Primary instance: keep the arguments for the Dart entrypoint and run.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_application_activate(application);
  *exit_status = 0;

  // FALSE: let GApplication emit GApplication::command-line / ::open for the
  // initial arguments too, so a cold-start tt:// link reaches Dart (app_links)
  // alongside the regular startup.
  return FALSE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&g_exit_dialog_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     // Single instance: secondary launches forward their
                                     // command line and open requests to the primary
                                     // over D-Bus instead of starting a new process.
                                     "flags", G_APPLICATION_HANDLES_COMMAND_LINE | G_APPLICATION_HANDLES_OPEN,
                                     nullptr));
}
