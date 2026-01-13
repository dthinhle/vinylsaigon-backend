
import { $getSelection, $isRangeSelection, $isNodeSelection, $getRoot } from "lexical"
import { ListNode } from "@lexical/list"
import { $getNearestNodeOfType } from "@lexical/utils"
import { SkeletonNode } from "../nodes/skeleton_node"

export function insertMediaNode(node) {
  const selection = $getSelection()

  if ($isRangeSelection(selection)) {
    if (!selection.isCollapsed()) {
      selection.removeText()
    }

    const anchor = selection.anchor.getNode()
    const listNode = $getNearestNodeOfType(anchor, ListNode)

    if (listNode) {
      // If inside a list, insert after the list structure
      listNode.insertAfter(node)
    } else {
      // Otherwise insert normally (splits paragraphs for block nodes)
      selection.insertNodes([node])
    }
  } else if ($isNodeSelection(selection)) {
    const nodes = selection.getNodes()
    const lastNode = nodes[nodes.length - 1]
    lastNode.insertAfter(node)
  } else {
    const root = $getRoot()
    root.append(node)
  }
}
