import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';

class PriorityWrapperBuilder extends BlockComponentBuilder {
  final BlockComponentBuilder baseBuilder;

  PriorityWrapperBuilder(this.baseBuilder);

  @override
  BlockComponentConfiguration get configuration => baseBuilder.configuration;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return _PriorityWrapperWidget(
      baseBuilder.build(blockComponentContext),
      key: blockComponentContext.node.key,
    );
  }

  @override
  BlockComponentValidate get validate => baseBuilder.validate;
}

class _PriorityWrapperWidget extends StatelessWidget with BlockComponentWidget {
  final BlockComponentWidget childWidget;

  _PriorityWrapperWidget(this.childWidget, {Key? key}) : super(key: key);

  @override
  bool get showActions => childWidget.showActions;

  @override
  Node get node => childWidget.node;

  @override
  BlockComponentConfiguration get configuration => childWidget.configuration;

  @override
  BlockComponentActionBuilder? get actionBuilder => childWidget.actionBuilder;

  @override
  BlockComponentActionTrailingBuilder? get actionTrailingBuilder => childWidget.actionTrailingBuilder;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        childWidget,
        const Positioned(
          left: -32,
          top: 0,
          child: Text('icon'),
        ),
      ],
    );
  }
}
