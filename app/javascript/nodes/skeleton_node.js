
import { DecoratorNode } from "lexical"

export class SkeletonNode extends DecoratorNode {
  static getType() {
    return "skeleton"
  }

  static clone(node) {
    return new SkeletonNode(node.__key)
  }

  constructor(key) {
    super(key)
  }

  createDOM(_config, _editor) {
    const div = document.createElement("div")
    div.className =
      "w-full h-64 bg-gray-100 animate-pulse rounded-lg flex items-center justify-center my-4"
    div.innerHTML = `
      <svg class="w-12 h-12 text-gray-300" fill="currentColor" viewBox="0 0 24 24">
         <path fill-rule="evenodd" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" clip-rule="evenodd" />
      </svg>
    `
    return div
  }

  updateDOM() {
    return false
  }

  exportJSON() {
    return {
      type: "skeleton",
      version: 1,
    }
  }

  static importJSON(_serializedNode) {
    return $createSkeletonNode()
  }

  isIsolated() {
    return true
  }

  decorate() {
    return null
  }

  isInline() {
    return false
  }
}

export function $createSkeletonNode() {
  return new SkeletonNode()
}

export function $isSkeletonNode(node) {
  return node instanceof SkeletonNode
}
