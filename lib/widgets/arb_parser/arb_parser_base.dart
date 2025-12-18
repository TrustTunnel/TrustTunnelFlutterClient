import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:trusttunnel/widgets/arb_parser/arb_item.dart';

typedef ArbWidgetBuilder = Widget Function(List<ArbItem> items);

class ArbParserBase extends StatefulWidget {
  final String data;
  final ArbWidgetBuilder builder;

  const ArbParserBase({
    super.key,
    required this.data,
    required this.builder,
  });

  @override
  State<ArbParserBase> createState() => _ArbParserBaseState();
}

class _ArbParserBaseState extends State<ArbParserBase> {
  late List<ArbItem> arbItems;

  @override
  void initState() {
    super.initState();
    arbItems = _parseArb(widget.data);
  }

  @override
  void didUpdateWidget(ArbParserBase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      arbItems = _parseArb(widget.data);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(arbItems);

  List<ArbItem> _parseArb(String data) {
    final dom.Document document = parse(data);

    return _parseNodes(document.body?.nodes ?? []);
  }

  List<ArbItem> _parseNodes(List<dom.Node> nodes) {
    List<ArbItem> items = [];
    for (final node in nodes) {
      items.addAll(_parseNode(node));
    }

    return items;
  }

  List<ArbItem> _parseNode(dom.Node node) {
    List<ArbItem> items = [];
    if (node is dom.Text) {
      if (node.text.isNotEmpty) {
        items.add(ArbItem(text: node.text, type: ArbItemType.plain));
      }
    } else if (node is dom.Element) {
      switch (node.localName) {
        case 'b':
          items.add(
            ArbItem(
              text: node.text,
              type: ArbItemType.bold,
            ),
          );
        default:
          throw UnimplementedError('Unknown node type: ${node.localName}');
      }
    }

    return items;
  }
}
