import { $createRangeSelection, $setSelection, DecoratorNode } from 'lexical'

export class YouTubeNode extends DecoratorNode {
  __id

  static getType() {
    return 'youtube'
  }

  static clone(node) {
    return new YouTubeNode(node.__id, node.__key)
  }

  static importJSON(serializedNode) {
    const node = $createYouTubeNode(serializedNode.videoID)
    return node
  }

  exportJSON() {
    return {
      type: 'youtube',
      videoID: this.__id,
      version: 1
    }
  }

  constructor(id, key) {
    super(key)
    this.__id = id
  }

  createDOM(config, editor) {
    const wrapper = document.createElement('div')
    wrapper.id = 'youtube-wrapper-' + this.getKey()
    wrapper.className = 'w-full my-4 rounded'
    wrapper.style.position = 'relative'
    wrapper.style.paddingBottom = '56.25%'
    wrapper.style.height = '0'
    wrapper.style.overflow = 'hidden'
    wrapper.style.cursor = 'pointer'
    wrapper.style.transition = 'outline 0.2s ease-in-out'
    wrapper.tabIndex = 0

    const iframe = document.createElement('iframe')
    iframe.style.position = 'absolute'
    iframe.style.top = '0'
    iframe.style.left = '0'
    iframe.style.width = '100%'
    iframe.style.height = '100%'
    iframe.src = `https://www.youtube.com/embed/${this.__id}`
    iframe.allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
    iframe.allowFullscreen = true
    iframe.title = 'YouTube video'
    iframe.style.pointerEvents = 'none'

    const embedBlockTheme = config.theme.embedBlock || {}
    if (embedBlockTheme.base) {
      iframe.className = embedBlockTheme.base
    }

    wrapper.appendChild(iframe)

    wrapper.addEventListener('click', (e) => {
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
    return document.getElementById('youtube-wrapper-' + this.getKey())
  }

  setUnselectedUI() {
    this.getWrapper().style.outline = "none"
  }


  updateDOM() {
    return false
  }

  getId() {
    return this.__id
  }

  getTextContent(_includeInert, _includeDirectionless) {
    return `https://www.youtube.com/watch?v=${this.__id}`
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

export function $createYouTubeNode(videoID) {
  return new YouTubeNode(videoID)
}

export function $isYouTubeNode(node) {
  return node instanceof YouTubeNode
}
