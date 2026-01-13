import { DecoratorNode, $createRangeSelection, $createNodeSelection, $getSelection, $setSelection, } from 'lexical'

const Direction = {
  east: 1 << 0,
  north: 1 << 3,
  south: 1 << 1,
  west: 1 << 2,
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max)
}

function calculateZoomLevel(element) {
  let zoom = 1
  let currentElement = element
  while (currentElement) {
    const elementZoom = Number(window.getComputedStyle(currentElement).getPropertyValue('zoom'))
    if (!isNaN(elementZoom) && elementZoom !== 1) {
      zoom *= elementZoom
    }
    currentElement = currentElement.parentElement
  }
  return zoom
}

const SNAP_THRESHOLD = 25

export class ImageNode extends DecoratorNode {
  __src
  __altText
  __width
  __height

  static getType() {
    return 'image'
  }

  static clone(node) {
    return new ImageNode(node.__src, node.__altText, node.__width, node.__height, node.__key)
  }

  constructor(src, altText, width, height, key) {
    super(key)
    this.__src = src
    this.__altText = altText
    this.__width = width || 'inherit'
    this.__height = height || 'inherit'
  }

  createDOM(config, editor) {
    const container = document.createElement('div')
    container.className = 'image-container'
    container.style.position = 'relative'
    container.style.display = 'inline-block'
    container.style.margin = '0'
    container.style.cursor = 'pointer'
    container.style.transition = 'outline 0.2s ease-in-out'
    container.tabIndex = 0

    const img = document.createElement('img')
    img.src = this.__src
    img.alt = this.__altText
    img.className = 'max-w-full h-auto rounded-lg'
    img.draggable = false

    if (this.__width !== 'inherit') {
      img.style.width = typeof this.__width === 'number' ? `${this.__width}px` : this.__width
    }
    if (this.__height !== 'inherit') {
      img.style.height = typeof this.__height === 'number' ? `${this.__height}px` : this.__height
    }

    container.appendChild(img)
    if (!editor.isEditable()) {
      return container
    }

    const resizeWrapper = this._createResizeWrapper(img, editor)
    container.appendChild(resizeWrapper)

    container.addEventListener('click', (e) => {
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

    return container
  }

  _createResizeWrapper(img, editor) {
    const wrapper = document.createElement('div')
    wrapper.className = 'image-resizer-wrapper'
    wrapper.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      display: none;
    `

    const resizers = [
      { className: 'image-resizer-n', direction: Direction.north },
      { className: 'image-resizer-ne', direction: Direction.north | Direction.east },
      { className: 'image-resizer-e', direction: Direction.east },
      { className: 'image-resizer-se', direction: Direction.south | Direction.east },
      { className: 'image-resizer-s', direction: Direction.south },
      { className: 'image-resizer-sw', direction: Direction.south | Direction.west },
      { className: 'image-resizer-w', direction: Direction.west },
      { className: 'image-resizer-nw', direction: Direction.north | Direction.west }
    ]

    resizers.forEach(({ className, direction }) => {
      const resizer = document.createElement('div')
      resizer.className = `image-resizer ${className}`
      resizer.addEventListener('pointerdown', (e) => this._handlePointerDown(e, direction, img, wrapper, editor))
      wrapper.appendChild(resizer)
    })

    return wrapper
  }

  _handlePointerDown(event, direction, img, wrapper, editor) {
    if (!editor.isEditable()) return

    event.preventDefault()

    const editorElement = editor.getRootElement()
    const maxWidthContainer = editorElement ? editorElement.getBoundingClientRect().width - 20 : 100
    const maxHeightContainer = editorElement ? editorElement.getBoundingClientRect().height - 20 : 100
    const minWidth = 100
    const minHeight = 100

    const { width, height } = img.getBoundingClientRect()
    const zoom = calculateZoomLevel(img)

    const positioning = {
      startWidth: width,
      startHeight: height,
      ratio: width / height,
      currentWidth: width,
      currentHeight: height,
      startX: event.clientX / zoom,
      startY: event.clientY / zoom,
      direction
    }

    const ew = direction === Direction.east || direction === Direction.west
    const ns = direction === Direction.north || direction === Direction.south
    const nwse = (direction & Direction.north && direction & Direction.west) ||
      (direction & Direction.south && direction & Direction.east)
    const cursorDir = ew ? 'ew' : ns ? 'ns' : nwse ? 'nwse' : 'nesw'

    if (editorElement) {
      editorElement.style.setProperty('cursor', `${cursorDir}-resize`, 'important')
    }
    document.body.style.setProperty('cursor', `${cursorDir}-resize`, 'important')
    document.body.style.setProperty('-webkit-user-select', 'none', 'important')

    wrapper.classList.add('image-control-wrapper--resizing')
    img.style.height = `${height}px`
    img.style.width = `${width}px`

    const handlePointerMove = (e) => {
      const isHorizontal = positioning.direction & (Direction.east | Direction.west)
      const isVertical = positioning.direction & (Direction.south | Direction.north)

      const zoom = calculateZoomLevel(img)

      if (isHorizontal && isVertical) {
        let diff = Math.floor(positioning.startX - e.clientX / zoom)
        diff = positioning.direction & Direction.east ? -diff : diff

        const width = clamp(positioning.startWidth + diff, minWidth, maxWidthContainer)
        const height = width / positioning.ratio


        if (width >= (maxWidthContainer - SNAP_THRESHOLD)) {
          img.style.width = ''
          img.style.height = ''
          if (img.attributes.style) {
            img.attributes.removeNamedItem('style')
          }
          positioning.currentHeight = 'inherit'
          positioning.currentWidth = 'inherit'
        } else {
          img.style.width = `${width}px`
          img.style.height = `${height}px`
          positioning.currentHeight = height
          positioning.currentWidth = width
        }
      } else if (isVertical) {
        let diff = Math.floor(positioning.startY - e.clientY / zoom)
        diff = positioning.direction & Direction.south ? -diff : diff

        const height = clamp(positioning.startHeight + diff, minHeight, maxHeightContainer)
        img.style.height = `${height}px`
        positioning.currentHeight = height
      } else {
        let diff = Math.floor(positioning.startX - e.clientX / zoom)
        diff = positioning.direction & Direction.east ? -diff : diff

        const width = clamp(positioning.startWidth + diff, minWidth, maxWidthContainer)

        console.log({ width, maxWidthContainer })
        if (width >= maxWidthContainer) {
          img.style.width = ''
          positioning.currentWidth = 'inherit'
        } else {
          img.style.width = `${width}px`
          positioning.currentWidth = width
        }
      }
    }

    const handlePointerUp = () => {
      wrapper.classList.remove('image-control-wrapper--resizing')

      if (editorElement) {
        editorElement.style.setProperty('cursor', 'text')
      }
      document.body.style.setProperty('cursor', 'default')
      document.body.style.setProperty('-webkit-user-select', 'auto')

      editor.update(() => {
        const node = editor.getElementByKey(this.__key)
        if (node) {
          const writable = this.getWritable()
          writable.__width = positioning.currentWidth
          writable.__height = positioning.currentHeight
        }
      })

      document.removeEventListener('pointermove', handlePointerMove)
      document.removeEventListener('pointerup', handlePointerUp)
    }

    document.addEventListener('pointermove', handlePointerMove)
    document.addEventListener('pointerup', handlePointerUp)
  }

  updateDOM(prevNode, dom) {
    const img = dom.querySelector('img')
    if (!img) return false

    if (prevNode.__src !== this.__src) {
      img.src = this.__src
    }
    if (prevNode.__altText !== this.__altText) {
      img.alt = this.__altText
    }
    if (prevNode.__width !== this.__width) {
      img.style.width = typeof this.__width === 'number' ? `${this.__width}px` : this.__width
    }
    if (prevNode.__height !== this.__height) {
      img.style.height = typeof this.__height === 'number' ? `${this.__height}px` : this.__height
    }
    return false
  }

  exportJSON() {
    return {
      altText: this.__altText,
      height: this.__height,
      src: this.__src,
      width: this.__width,
      type: 'image',
      version: 1
    }
  }

  static importJSON(serializedNode) {
    const { altText, height, width, src } = serializedNode
    return $createImageNode({ altText, height, src, width })
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

export function $createImageNode({ altText, height, src, width }) {
  return new ImageNode(src, altText, width, height)
}

export function $isImageNode(node) {
  return node instanceof ImageNode
}
