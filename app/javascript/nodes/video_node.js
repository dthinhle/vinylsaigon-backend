import {
  $createRangeSelection,
  $setSelection,
  DecoratorNode
} from "lexical"

export class VideoNode extends DecoratorNode {
  __src
  __wrapper

  static getType() {
    return "video"
  }

  static clone(node) {
    return new VideoNode(node.__src, node.__key)
  }

  static importJSON(serializedNode) {
    const node = $createVideoNode(serializedNode.src)
    return node
  }

  exportJSON() {
    return {
      type: "video",
      src: this.__src,
      version: 1,
    }
  }

  constructor(src, key) {
    super(key)
    this.__src = src
  }

  createDOM(config, editor) {
    const wrapper = document.createElement("div")
    wrapper.id = 'video-wrapper-' + this.getKey()
    wrapper.className = "w-full my-4 rounded"
    wrapper.style.position = "relative"
    wrapper.style.paddingBottom = "56.25%"
    wrapper.style.height = "0"
    wrapper.style.overflow = "hidden"
    wrapper.style.cursor = "pointer"
    wrapper.tabIndex = 0

    const video = document.createElement("video")
    video.style.position = "absolute"
    video.style.top = "0"
    video.style.left = "0"
    video.style.width = "100%"
    video.style.height = "100%"
    video.src = this.__src
    video.controls = true
    video.controlsList = "nodownload"
    video.preload = "metadata"
    video.className = "rounded"

    const embedBlockTheme = config.theme.embedBlock || {}
    if (embedBlockTheme.base) {
      video.classList.add(embedBlockTheme.base)
    }

    wrapper.appendChild(video)

    wrapper.addEventListener("click", (e) => {
      e.preventDefault()
      editor.update(() => {
        const rangeSelection = $createRangeSelection();

        const nodeParent = this.getParent();
        const index = this.getIndexWithinParent();
        rangeSelection.anchor.set(nodeParent.getKey(), index, 'element')
        rangeSelection.focus.set(nodeParent.getKey(), index + 1, 'element')
        $setSelection(rangeSelection)
      })
    })

    return wrapper
  }

  setSelectedUI() {
    this.getWrapper().style.outline = "2px solid #3399FF"
  }

  getWrapper() {
    return document.getElementById('video-wrapper-' + this.getKey())
  }

  setUnselectedUI() {
    this.getWrapper().style.outline = "none"
  }

  updateDOM() {
    return false
  }

  getSrc() {
    return this.__src
  }

  getTextContent(_includeInert, _includeDirectionless) {
    return this.__src
  }

  decorate() {
    return null
  }

  isIsolated() {
    return true
  }

  isInline() {
    return false
  }
}

export function $createVideoNode(src) {
  return new VideoNode(src)
}

export function $isVideoNode(node) {
  return node instanceof VideoNode
}
