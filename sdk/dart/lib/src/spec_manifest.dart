import 'ids.dart';
import 'model.dart';
import 'spec.dart';

/// Builds the GUI manifest for [spec]: every command, group and sidebar
/// entry, in declaration order.
GuiManifest manifestFromSpec(CliSpec spec) {
  final groups = <GuiGroup>[];
  final commands = <GuiCommand>[];
  final navigation = <GuiNavItem>[];

  void visit(CliNode node, List<String> path, String? groupId) {
    final here = <String>[...path, node.name];
    final id = commandId(here);
    switch (node) {
      case CliGroup():
        groups.add(
          GuiGroup(
            id: id,
            label: node.title,
            icon: node.icon,
            description: node.description,
            parent: groupId,
          ),
        );
        if (node.navigation) {
          navigation.add(
            GuiNavItem.command(
              id,
              node.title,
              commandId([...here, node.sidebarCommand!]),
              icon: node.icon,
            ),
          );
        }
        for (final child in node.children) {
          visit(child, here, id);
        }
      case CliCommand():
        commands.add(
          GuiCommand(
            id: id,
            argv: [
              ...here,
              if (node.output.format == GuiFormat.json) ...spec.jsonArgs,
            ],
            title: node.title,
            description: node.description,
            parameters: [
              for (final p in node.parameters)
                if (!p.hidden) p,
            ],
            output: node.output,
            destructive: node.destructive,
            interactive: node.interactive,
            longRunning: node.longRunning,
            requires: node.requires,
            hidden: node.guiHidden,
            group: groupId,
          ),
        );
        if (node.navigation) {
          navigation.add(
            GuiNavItem.command(id, node.title, id, icon: node.icon),
          );
        }
    }
  }

  for (final node in spec.nodes) {
    visit(node, const <String>[], null);
  }
  return GuiManifest(
    cli: GuiCliInfo(
      name: spec.name,
      version: spec.version,
      displayName: spec.displayName,
      description: spec.description,
    ),
    navigation: navigation,
    commands: commands,
    groups: groups,
  );
}
