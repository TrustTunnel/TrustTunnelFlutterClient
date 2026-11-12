import 'package:flutter/material.dart';
import 'package:trusttunnel/common/constants/app_constants.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/widgets/custom_alert_dialog.dart';
import 'package:trusttunnel/widgets/inputs/custom_text_field.dart';

/// {@template add_server_by_link_dialog}
/// Dialog for adding a server by pasting a `tt://` deep link.
///
/// Returns the parsed [ServerData] via `Navigator.pop` on success,
/// `null` when dismissed.
/// {@endtemplate}
class AddServerByLinkDialog extends StatefulWidget {
  const AddServerByLinkDialog({super.key});

  @override
  State<AddServerByLinkDialog> createState() => _AddServerByLinkDialogState();
}

class _AddServerByLinkDialogState extends State<AddServerByLinkDialog> {
  final TextEditingController _linkController = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomAlertDialog(
    title: context.ln.addServerViaLink,
    scrollable: true,
    content: Padding(
      padding: const EdgeInsets.only(top: 24),
      child: CustomTextField(
        label: context.ln.addServerViaLinkLabel,
        hint: context.ln.addServerViaLinkLabel,
        controller: _linkController,
        error: _error,
        onChanged: (_) {
          if (_error != null) {
            setState(() => _error = null);
          }
        },
      ),
    ),
    actionsBuilder: (spacing) => [
      TextButton(
        onPressed: _loading ? null : context.pop,
        child: Text(context.ln.cancel),
      ),
      FilledButton(
        onPressed: _loading ? null : _submit,
        child: _loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(context.ln.add),
      ),
    ],
  );

  Future<void> _submit() async {
    final link = _linkController.text.trim();
    if (link.isEmpty || _loading) {
      return;
    }

    if (!_isValidTrustTunnelLink(link)) {
      setState(() => _error = context.ln.addServerViaLinkInvalid);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repositoryFactory = context.repositoryFactory;
      final serverData = await repositoryFactory.deepLinkRepository.parseDataFromLink(deepLink: link);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(serverData);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = ExceptionUtils.toPresentationException(exception: error).toLocalizedString(context);
      });
    }
  }

  bool _isValidTrustTunnelLink(String link) {
    final Uri? uri;
    try {
      uri = Uri.parse(link);
    } on FormatException {
      return false;
    }

    if (uri.scheme.toLowerCase() != AppConstants.deepLinkScheme) {
      return false;
    }

    // The official payload lives in the query (`tt://?...`), but keep links
    // with a path payload acceptable and let the decoder decide.
    return uri.hasQuery || uri.path.isNotEmpty;
  }
}
