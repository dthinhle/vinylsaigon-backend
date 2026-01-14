import { computePosition, flip, offset, shift } from "@floating-ui/dom"
import { Controller } from "@hotwired/stimulus"
import { $createCodeNode, CodeHighlightNode, CodeNode } from "@lexical/code"
import { createEmptyHistoryState, registerHistory } from "@lexical/history"
import { $toggleLink, AutoLinkNode, LinkNode } from "@lexical/link"
import {
  INSERT_ORDERED_LIST_COMMAND,
  INSERT_UNORDERED_LIST_COMMAND,
  ListItemNode,
  ListNode,
  registerList,
} from "@lexical/list"
import {
  $createHeadingNode,
  $createQuoteNode,
  HeadingNode,
  QuoteNode,
  registerRichText,
} from "@lexical/rich-text"
import { $setBlocksType } from "@lexical/selection"
import { TableCellNode, TableNode, TableRowNode } from "@lexical/table"
import {
  $createParagraphNode,
  $getNodeByKey,
  $getRoot,
  $getSelection,
  $isRangeSelection,
  COMMAND_PRIORITY_EDITOR,
  COMMAND_PRIORITY_HIGH,
  COMMAND_PRIORITY_LOW,
  createCommand,
  createEditor,
  DecoratorNode,
  FORMAT_TEXT_COMMAND,
  KEY_ENTER_COMMAND,
  KEY_TAB_COMMAND,
  KEY_DELETE_COMMAND,
  KEY_BACKSPACE_COMMAND,
  PASTE_COMMAND,
  REDO_COMMAND,
  UNDO_COMMAND,
} from "lexical"
import { $createImageNode, ImageNode } from "../nodes/image_node"
import { $createSkeletonNode, SkeletonNode } from "../nodes/skeleton_node"
import { $createVideoNode, VideoNode } from "../nodes/video_node"
import { $createYouTubeNode, YouTubeNode } from "../nodes/youtube_node"
import { insertMediaNode } from "../utils/lexical_node_insertion"
import { LexicalPasteHandler } from "../utils/lexical_paste_handler"

const INSERT_IMAGE_COMMAND = createCommand("INSERT_IMAGE_COMMAND")
const INSERT_YOUTUBE_COMMAND = createCommand("INSERT_YOUTUBE_COMMAND")
const INSERT_VIDEO_COMMAND = createCommand("INSERT_VIDEO_COMMAND")

class ImageUploadError extends Error {
  constructor(message) {
    super(message) // (1)
    this.name = "ImageUploadError" // (2)
  }
}

export default class extends Controller {
  static targets = ["editor", "toolbar", "input"];
  static values = {
    content: String,
    placeholder: { type: String, default: "Start typing..." },
    uploadUrl: { type: String, default: "/admin/blogs/upload_image" },
    videoUploadUrl: { type: String, default: "/admin/blogs/upload_video" },
    editable: { type: Boolean, default: true },
  };

  connect() {
    this.initializeEditor()
    this.registerPlugins()
    if (this.editableValue) {
      this.createToolbar()
    }
    this.loadContent()
    this.setupEventListeners()
    this.lastEnterTime = 0
  }

  initializeEditor() {
    const editorConfig = {
      namespace: "LexicalEditor",
      theme: {
        paragraph: "mb-2 border-l-2 border-gray-400 pl-2 rounded-l-[2px]",
        heading: {
          h1: "text-3xl font-bold mb-4 mt-6",
          h2: "text-2xl font-bold mb-3 mt-5",
          h3: "text-xl font-bold mb-2 mt-4",
          h4: "text-[19px] font-bold mb-2 mt-4",
          h5: "text-lg font-bold mb-1 mt-2",
          h6: "text-[17px] font-bold mb-1 mt-2",
        },
        list: {
          nested: { listitem: "ml-4" },
          ol: "list-decimal ml-6 mb-2",
          ul: "list-disc ml-6 mb-2",
          listitem: "mb-1",
        },
        link: "text-blue-600 underline hover:text-blue-800",
        text: {
          bold: "font-bold",
          italic: "italic",
          underline: "underline",
          strikethrough: "line-through",
          code: "bg-gray-100 px-1 py-0.5 rounded font-mono text-sm",
        },
        code: "bg-gray-900 text-white p-4 rounded-lg font-mono text-sm block my-4 overflow-x-auto",
        quote: "border-l-4 border-gray-300 pl-4 italic my-4 text-gray-700",
        image: "my-4",
      },
      onError: (error) => {
        console.error("Lexical error:", error)
      },
      nodes: [
        HeadingNode,
        ListNode,
        ListItemNode,
        QuoteNode,
        CodeNode,
        CodeHighlightNode,
        LinkNode,
        AutoLinkNode,
        TableNode,
        TableCellNode,
        TableRowNode,
        ImageNode,
        YouTubeNode,
        VideoNode,
        SkeletonNode,
      ],
      editable: this.editableValue,
    }

    this.editor = createEditor(editorConfig)

    this.history = createEmptyHistoryState()
    registerHistory(this.editor, this.history, 200)

    this.editor.setRootElement(this.editorTarget)
    this.editorTarget.contentEditable = true
    if (!this.editorTarget.dataset.minHeight) {
      this.editorTarget.dataset.minHeight = "300"
    }
    this.editorTarget.contentEditable = this.editableValue
    this.editorTarget.className = this.editableValue
      ? "min-h-[attr(data-min-height_px)] p-4 border border-gray-300 rounded-lg focus:outline-none focus:ring-blue-500 prose max-w-none"
      : "min-h-[attr(data-min-height_px)] p-4 prose max-w-none"
    this.editorTarget.setAttribute("role", "textbox")
    this.editorTarget.setAttribute("aria-multiline", "true")
    this.editorTarget.setAttribute("aria-placeholder", this.placeholderValue)
  }

  registerPlugins() {
    registerRichText(this.editor)
    registerList(this.editor)

    this.registerListEscapeHandlers()

    this.editor.registerCommand(
      INSERT_IMAGE_COMMAND,
      async (payload) => {
        const { file, src, altText } = payload

        let skeletonKey = null
        const isUpload = file || (src && this.isExternalUrl(src))

        if (isUpload) {
          this.editor.update(() => {
            const skeleton = $createSkeletonNode()
            insertMediaNode(skeleton)
            skeletonKey = skeleton.getKey()
          })
        }

        let imageUrl = src

        try {
          if (file) {
            imageUrl = await this.uploadImageFile(file)
          } else if (src && this.isExternalUrl(src)) {
            imageUrl = await this.uploadImageUrl(src)
          }
        } catch (error) {
          if (skeletonKey) {
            this.editor.update(() => {
              const node = $getNodeByKey(skeletonKey)
              if (node) node.remove()
            })
          }
          throw error
        }

        this.editor.update(() => {
          const imageNode = $createImageNode({
            src: imageUrl,
            altText: altText || file?.name || "Uploaded image",
            width: "inherit",
            height: "inherit",
          })

          if (skeletonKey) {
            const skeleton = $getNodeByKey(skeletonKey)
            if (skeleton) {
              skeleton.replace(imageNode)
              return
            }
            return
          }

          insertMediaNode(imageNode)
        })

        return true
      },
      COMMAND_PRIORITY_EDITOR,
    )

    this.pasteHandler = new LexicalPasteHandler(this.editor)

    this.editor.registerCommand(
      PASTE_COMMAND,
      (event) => this.pasteHandler.handlePaste(event),
      COMMAND_PRIORITY_LOW,
    )

    this.editor.registerCommand(
      INSERT_YOUTUBE_COMMAND,
      (videoID) => {
        this.editor.update(() => {
          const youtubeNode = $createYouTubeNode(videoID)
          insertMediaNode(youtubeNode)
        })
        return true
      },
      COMMAND_PRIORITY_EDITOR,
    )

    this.editor.registerCommand(
      INSERT_VIDEO_COMMAND,
      async (payload) => {
        const { file } = payload

        if (!file) {
          return false
        }

        let skeletonKey = null

        this.editor.update(() => {
          const skeleton = $createSkeletonNode()
          insertMediaNode(skeleton)
          skeletonKey = skeleton.getKey()
        })

        let videoUrl
        try {
          videoUrl = await this.uploadVideoFile(file)
        } catch (error) {
          if (skeletonKey) {
            this.editor.update(() => {
              const node = $getNodeByKey(skeletonKey)
              if (node) node.remove()
            })
          }
          throw error
        }

        this.editor.update(() => {
          const videoNode = $createVideoNode(videoUrl)

          if (skeletonKey) {
            const skeleton = $getNodeByKey(skeletonKey)
            if (skeleton) {
              skeleton.replace(videoNode)
            }
            return
          }

          insertMediaNode(videoNode)
        })

        return true
      },
      COMMAND_PRIORITY_EDITOR,
    )
  }

  registerListEscapeHandlers() {
    this.editor.registerCommand(
      KEY_TAB_COMMAND,
      (event) => {
        if (event.shiftKey) {
          const selection = $getSelection()
          if (!$isRangeSelection(selection)) return false

          const nodes = selection.getNodes()
          let listItemNode = null

          for (const node of nodes) {
            let current = node
            while (current) {
              if (current instanceof ListItemNode) {
                listItemNode = current
                break
              }
              current = current.getParent()
            }
            if (listItemNode) break
          }

          if (listItemNode) {
            event.preventDefault()
            this.escapeList(listItemNode)
            return true
          }
        }
        return false
      },
      COMMAND_PRIORITY_HIGH,
    )

    this.editor.registerCommand(
      KEY_DELETE_COMMAND,
      (event) => {
        const selection = $getSelection()
        if (!$isRangeSelection(selection)) return false
        const nodes = selection.getNodes()
        for (const node of nodes) {
          if (node.getType() === "paragraph" && node.getTextContent().length === 0) {
            node.remove()
          }
        }
      },
      COMMAND_PRIORITY_LOW,
    )

    this.editor.registerCommand(
      KEY_BACKSPACE_COMMAND,
      (event) => {
        const selection = $getSelection()
        if (!$isRangeSelection(selection)) return false
        const nodes = selection.getNodes()
        for (const node of nodes) {
          if (node.getType() === "paragraph" && node.getTextContent().length === 0) {
            node.remove()
          }
        }
      },
      COMMAND_PRIORITY_LOW,
    )

    this.editor.registerCommand(
      KEY_ENTER_COMMAND,
      (event) => {
        const now = Date.now()
        const timeSinceLastEnter = now - this.lastEnterTime

        if (timeSinceLastEnter < 500) {
          const selection = $getSelection()
          if (!$isRangeSelection(selection)) return false

          const nodes = selection.getNodes()
          let listItemNode = null

          for (const node of nodes) {
            let current = node
            while (current) {
              if (current instanceof ListItemNode) {
                listItemNode = current
                break
              }
              current = current.getParent()
            }
            if (listItemNode) break
          }

          if (listItemNode) {
            event.preventDefault()
            this.escapeList(listItemNode)
            this.lastEnterTime = 0
            return true
          }
        }

        this.lastEnterTime = now
        return false
      },
      COMMAND_PRIORITY_HIGH,
    )
  }

  escapeList(listItemNode) {
    this.editor.update(() => {
      const listNode = listItemNode.getParent()
      if (!listNode || !(listNode instanceof ListNode)) return

      const allListItems = listNode.getChildren()
      const currentIndex = allListItems.indexOf(listItemNode)

      if (currentIndex === -1) return

      const itemsToEscape = allListItems.slice(currentIndex)

      itemsToEscape.reverse().forEach((item) => {
        const children = item.getChildren()
        const paragraph = $createParagraphNode()

        children.forEach((child) => {
          paragraph.append(child)
        })

        listNode.insertAfter(paragraph)
        item.remove()
      })

      if (listNode.getChildren().length === 0) {
        listNode.remove()
      }
    })
  }

  createToolbar() {
    const toolbar = document.createElement("div")
    toolbar.className =
      "flex flex-wrap gap-1 p-2 border border-gray-300 rounded-t-lg bg-gray-50 mb-0"
    toolbar.setAttribute("role", "toolbar")

    const buttonGroups = [
      [
        {
          icon: "undo",
          command: () => this.undo(),
          title: "Undo (Ctrl+Z)",
          ariaLabel: "Undo",
        },
        {
          icon: "redo",
          command: () => this.redo(),
          title: "Redo (Ctrl+Y)",
          ariaLabel: "Redo",
        },
      ],
      [
        {
          icon: "format_bold",
          command: () => this.formatText("bold"),
          title: "Bold (Ctrl+B)",
          ariaLabel: "Bold",
        },
        {
          icon: "format_italic",
          command: () => this.formatText("italic"),
          title: "Italic (Ctrl+I)",
          ariaLabel: "Italic",
        },
        {
          icon: "format_underlined",
          command: () => this.formatText("underline"),
          title: "Underline (Ctrl+U)",
          ariaLabel: "Underline",
        },
      ],
      [
        {
          icon: "title",
          command: (e) => this.toggleHeadingDropdown(e.target),
          title: "Headings",
          ariaLabel: "Headings",
          isDropdown: true,
        },
      ],
      [
        {
          icon: "format_list_bulleted",
          command: () => this.insertList("bullet"),
          title: "Bullet List",
          ariaLabel: "Bullet List",
        },
        {
          icon: "format_list_numbered",
          command: () => this.insertList("number"),
          title: "Numbered List",
          ariaLabel: "Numbered List",
        },
      ],
      [
        {
          icon: "link",
          command: () => this.showLinkDialog(),
          title: "Insert Link",
          ariaLabel: "Insert Link",
        },
        {
          icon: "image",
          command: () => this.showImageDialog(),
          title: "Insert Image",
          ariaLabel: "Insert Image",
        },
        {
          icon: "video_library",
          command: () => this.showYouTubeDialog(),
          title: "Insert YouTube Video",
          ariaLabel: "Insert YouTube Video",
        },
        {
          icon: "videocam",
          command: () => this.showVideoDialog(),
          title: "Upload Video",
          ariaLabel: "Upload Video",
        },
      ],
      [
        {
          icon: "format_quote",
          command: () => this.insertQuote(),
          title: "Block Quote",
          ariaLabel: "Block Quote",
        },
        {
          icon: "code",
          command: () => this.insertCode(),
          title: "Code Block",
          ariaLabel: "Code Block",
        },
      ],
    ]

    buttonGroups.forEach((group, groupIndex) => {
      if (groupIndex > 0) {
        const separator = document.createElement("div")
        separator.className = "w-px bg-gray-300 mx-1"
        toolbar.appendChild(separator)
      }

      group.forEach(({ icon, command, title, ariaLabel, isDropdown }) => {
        const button = document.createElement("button")
        button.type = "button"
        button.title = title
        button.setAttribute("aria-label", ariaLabel)
        button.className =
          "px-2 py-1 text-sm font-medium text-gray-700 hover:bg-gray-200 rounded transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 flex items-center gap-1"

        const iconElement = document.createElement("span")
        iconElement.className = "material-icons text-base!"
        iconElement.textContent = icon
        button.appendChild(iconElement)

        if (isDropdown) {
          const arrowIcon = document.createElement("span")
          arrowIcon.className = "material-icons text-sm"
          arrowIcon.textContent = "arrow_drop_down"
          button.appendChild(arrowIcon)
        }

        button.addEventListener("click", (e) => {
          e.preventDefault()
          command(e)
        })
        toolbar.appendChild(button)
      })
    })

    this.editorTarget.parentNode.insertBefore(toolbar, this.editorTarget)
    this.editorTarget.classList.remove("rounded-lg")
    this.editorTarget.classList.add("rounded-b-lg", "border-t-0")
  }

  undo() {
    this.ensureSelection()
    this.editor.dispatchCommand(UNDO_COMMAND, undefined)
  }

  redo() {
    this.ensureSelection()
    this.editor.dispatchCommand(REDO_COMMAND, undefined)
  }

  formatText(format) {
    this.ensureSelection()
    this.editor.dispatchCommand(FORMAT_TEXT_COMMAND, format)
  }

  formatHeading(tag) {
    this.ensureSelection()

    this.editor.update(() => {
      const selection = $getSelection()
      if (selection) {
        if (tag === "normal") {
          // Convert to paragraph
          $setBlocksType(selection, () => $createParagraphNode())
        } else {
          $setBlocksType(selection, () => $createHeadingNode(tag))
        }
      }
    })
  }

  insertList(listType) {
    this.ensureSelection()

    this.editor.update(() => {
      const selection = $getSelection()
      if (!$isRangeSelection(selection)) return

      const nodes = selection.getNodes()
      const selectedListItems = []

      for (const node of nodes) {
        let current = node
        while (current) {
          if (current instanceof ListItemNode) {
            if (!selectedListItems.includes(current)) {
              selectedListItems.push(current)
            }
            break
          }
          current = current.getParent()
        }
      }

      if (selectedListItems.length > 0) {
        selectedListItems.forEach((listItem) => {
          const children = listItem.getChildren()
          listItem.insertAfter($createParagraphNode().append(...children))
          listItem.remove()
        })
      } else {
        if (listType === "bullet") {
          this.editor.dispatchCommand(INSERT_UNORDERED_LIST_COMMAND, undefined)
        } else {
          this.editor.dispatchCommand(INSERT_ORDERED_LIST_COMMAND, undefined)
        }
      }
    })
  }

  showLinkDialog() {
    this.ensureSelection()

    const currentTextContent = this.editor.read(() => $getSelection().getTextContent())

    const dialog = document.createElement("div")
    dialog.className =
      "fixed inset-0 bg-gray-950/50 flex items-center justify-center z-80"

    const dialogContent = document.createElement("div")
    dialogContent.className = "bg-white rounded-lg p-6 max-w-md w-full mx-4"

    const textInputValue = currentTextContent.length > 0 ? "" : `<div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Link Text</label>
          <input type="text" placeholder="Click here" class="link-text-input input input-bordered text-sm w-full px-3 py-2 rounded border border-gray-300 focus:ring-sky-500" />
          <p class="text-xs text-gray-500 mt-1">The text that will be displayed (optional)</p>
        </div>`
    dialogContent.innerHTML = `
      <h3 class="text-lg font-semibold mb-4">Insert Link</h3>
      <form class="link-form space-y-4">
        ${textInputValue}
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">URL</label>
          <input type="text" placeholder="/product-name" class="link-url-input input input-bordered text-sm w-full px-3 py-2 rounded border border-gray-300 focus:ring-sky-500" />
        </div>
        <div class="flex gap-2 justify-end">
          <button type="button" class="cancel-btn btn btn-primary text-sm px-4 py-2 rounded border border-gray-300 hover:bg-gray-50">Cancel</button>
          <button type="submit" class="confirm-btn btn btn-primary text-sm px-4 py-2 rounded bg-gray-950 hover:bg-gray-700 flex items-center transition cursor-pointer">
            <span class="material-icons text-white items-center text-base! mr-2 -ml-1">check_circle</span>
            <span class="text-white">Insert</span>
          </button>
        </div>
      </form>
    `

    dialog.appendChild(dialogContent)
    document.body.appendChild(dialog)

    const form = dialogContent.querySelector(".link-form")
    const textInput = dialogContent.querySelector(".link-text-input")
    const urlInput = dialogContent.querySelector(".link-url-input")
    const cancelBtn = dialogContent.querySelector(".cancel-btn")

    const closeDialog = () => dialog.remove()

    const handleSubmit = (e) => {
      e.preventDefault()
      const url = urlInput.value.trim()
      const text = textInput ? textInput.value.trim() : null

      if (url) {
        this.editor.update(() => {
          const selection = $getSelection()
          if ($isRangeSelection(selection)) {
            if (text) {
              selection.insertText(text)
            }
            $toggleLink({ url })
          }
        })
        closeDialog()
      } else {
        alert("Please enter a URL")
      }
    }

    form.addEventListener("submit", handleSubmit)
    cancelBtn.addEventListener("click", closeDialog)
    dialog.addEventListener("click", (e) => {
      if (e.target === dialog) closeDialog()
    })

    textInput.focus()
  }

  async toggleHeadingDropdown(buttonElement) {
    const existingDropdown = document.querySelector(".heading-dropdown")
    if (existingDropdown) {
      existingDropdown.remove()
      return
    }

    const dropdown = document.createElement("div")
    dropdown.className =
      "heading-dropdown bg-white border border-gray-300 rounded shadow-lg z-50 w-32"
    dropdown.style.minWidth = "150px"

    const headings = [
      { tag: "h1", label: "Heading 1" },
      { tag: "h2", label: "Heading 2" },
      { tag: "h3", label: "Heading 3" },
      { tag: "h4", label: "Heading 4" },
      { tag: "h5", label: "Heading 5" },
      { tag: "h6", label: "Heading 6" },
      { tag: "normal", label: "Normal" },
    ]

    headings.forEach(({ tag, label }) => {
      const item = document.createElement("button")
      item.type = "button"
      item.className = "w-full text-left px-4 py-2 hover:bg-gray-100 text-sm"
      item.textContent = label
      item.addEventListener("click", (e) => {
        e.preventDefault()
        this.formatHeading(tag)
        dropdown.remove()
      })
      dropdown.appendChild(item)
    })

    document.body.appendChild(dropdown)

    const { x, y } = await computePosition(buttonElement, dropdown, {
      placement: "bottom-center",
      middleware: [offset(4), flip(), shift({ padding: 8 })],
    })

    Object.assign(dropdown.style, {
      position: "absolute",
      top: `${y}px`,
      left: `${x}px`,
    })

    const closeDropdown = (e) => {
      if (!dropdown.contains(e.target) && e.target !== buttonElement) {
        dropdown.remove()
        document.removeEventListener("click", closeDropdown)
      }
    }
    setTimeout(() => document.addEventListener("click", closeDropdown), 0)
  }

  showImageDialog() {
    const dialog = document.createElement("div")
    dialog.className =
      "fixed inset-0 bg-gray-950/50 flex items-center justify-center z-80"

    const dialogContent = document.createElement("div")
    dialogContent.className = "bg-white rounded-lg p-6 max-w-md w-full mx-4"

    dialogContent.innerHTML = `
      <h3 class="text-lg font-semibold mb-4">Insert Image</h3>
      <form class="image-form space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Upload from file</label>
          <input type="file" multiple accept="image/*" class="image-file-input input input-bordered text-sm w-full px-3 py-2 rounded border border-gray-300 focus:ring-sky-500" />
          <ol class="text-xs text-gray-500 mt-1 ml-4 list-decimal" id="uploaded-images-info">
          </ol>
        </div>
        <div class="text-center text-sm text-gray-500">OR</div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Image URL</label>
          <input type="text" placeholder="https://example.com/image.jpg" class="image-url-input input input-bordered text-sm w-full px-3 py-2 rounded border border-gray-300 focus:ring-sky-500" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Alt text (optional)</label>
          <input type="text" placeholder="Description of image" class="image-alt-input input input-bordered text-sm w-full px-3 py-2 rounded border border-gray-300 focus:ring-sky-500" />
        </div>
        <div class="flex gap-2 justify-end">
          <button type="button" class="cancel-btn btn btn-primary text-sm px-4 py-2 rounded border border-gray-300 hover:bg-gray-50">Cancel</button>
              <button type="submit" class="confirm-btn btn btn-primary text-sm px-4 py-2 rounded bg-gray-950 hover:bg-gray-700 flex items-center transition cursor-pointer">
            <span class="material-icons text-white items-center text-base! mr-2 -ml-1">check_circle</span>
            <span class="text-white">Insert</span>
          </button>
        </div>
      </form>
    `

    dialog.appendChild(dialogContent)
    document.body.appendChild(dialog)

    const form = dialogContent.querySelector(".image-form")
    const fileInput = dialogContent.querySelector(".image-file-input")
    const urlInput = dialogContent.querySelector(".image-url-input")
    const altInput = dialogContent.querySelector(".image-alt-input")
    const cancelBtn = dialogContent.querySelector(".cancel-btn")

    fileInput.addEventListener("change", () => {
      const infoList = dialogContent.querySelector("#uploaded-images-info")
      infoList.innerHTML = ""
      for (const file of fileInput.files) {
        const listItem = document.createElement("li")
        listItem.textContent = `${file.name} (${(
          file.size / 1024
        ).toFixed(2)} KB)`
        infoList.appendChild(listItem)
      }
    })

    const closeDialog = () => dialog.remove()

    const handleSubmit = async (e) => {
      e.preventDefault()
      const files = fileInput.files
      const url = urlInput.value.trim()
      const altText = altInput.value.trim() || "Image"

      if (files.length > 0) {
        for (const file of files) {
          this.editor.dispatchCommand(INSERT_IMAGE_COMMAND, { file, altText })
        }
        closeDialog()
      } else if (url) {
        this.editor.dispatchCommand(INSERT_IMAGE_COMMAND, {
          src: url,
          altText,
        })
        closeDialog()
      } else {
        alert("Please select a file or enter an image URL")
      }
    }

    fileInput.focus()

    form.addEventListener("submit", handleSubmit)
    cancelBtn.addEventListener("click", closeDialog)
    dialog.addEventListener("click", (e) => {
      if (e.target === dialog) closeDialog()
    })
  }

  insertImageFromFile() {
    const input = document.createElement("input")
    input.type = "file"
    input.accept = "image/*"
    input.onchange = async (e) => {
      const file = e.target.files[0]
      if (file) {
        this.editor.dispatchCommand(INSERT_IMAGE_COMMAND, { file })
      }
    }
    input.click()
  }

  insertImageFromUrl() {
    const url = prompt("Enter image URL:")
    if (url) {
      const altText = prompt("Enter alt text (optional):") || "Image"
      this.editor.dispatchCommand(INSERT_IMAGE_COMMAND, { src: url, altText })
    }
  }

  async uploadImageFile(file) {
    const formData = new FormData()
    formData.append("file", file)

    const csrfToken = document.querySelector('meta[name="csrf-token"]').content

    try {
      const response = await fetch(this.uploadUrlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": csrfToken,
        },
        body: formData,
      })

      if (!response.ok) {
        const errorData = await response.json()
        const errorMessage = errorData.error || "Upload failed"
        this.showToast(errorMessage, "error")
        throw new Error(errorMessage)
      }

      const data = await response.json()
      return data.location
    } catch (error) {
      console.error("Image upload failed:", error)
      if (!error.message.includes("error")) {
        this.showToast("Failed to upload image. Please try again.", "error")
      }
      throw error
    }
  }

  async uploadImageUrl(url) {
    const formData = new FormData()
    formData.append("url", url)

    const csrfToken = document.querySelector('meta[name="csrf-token"]').content

    try {
      const response = await fetch(this.uploadUrlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": csrfToken,
        },
        body: formData,
      })

      if (!response.ok) {
        const errorData = await response.json()
        const errorMessage = errorData.error || "Upload failed"

        throw new ImageUploadError(errorMessage)
      }

      const data = await response.json()
      return data.location
    } catch (error) {
      if (error instanceof ImageUploadError) {
        console.warn("Image URL upload failed:", error)
        this.showToast(error.message, "error")
      } else if (!error.message.includes("error")) {
        console.error("Image URL upload failed:", error)
        this.showToast(
          "Failed to upload image from URL. Please try again.",
          "error",
        )
      }
      throw error
    }
  }

  async uploadVideoFile(file) {
    const formData = new FormData()
    formData.append("file", file)

    const csrfToken = document.querySelector('meta[name="csrf-token"]').content

    try {
      const response = await fetch(this.videoUploadUrlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": csrfToken,
        },
        body: formData,
      })

      if (!response.ok) {
        const errorData = await response.json()
        const errorMessage = errorData.error || "Upload failed"
        this.showToast(errorMessage, "error")
        throw new Error(errorMessage)
      }

      const data = await response.json()
      return data.location
    } catch (error) {
      console.error("Video upload failed:", error)
      if (!error.message.includes("error")) {
        this.showToast("Failed to upload video. Please try again.", "error")
      }
      throw error
    }
  }

  isExternalUrl(url) {
    try {
      const urlObj = new URL(url)
      return urlObj.protocol === "http:" || urlObj.protocol === "https:"
    } catch {
      return false
    }
  }

  showYouTubeDialog() {
    const dialog = document.createElement("div")
    dialog.className =
      "fixed inset-0 bg-gray-950/50 flex items-center justify-center z-80"

    const dialogContent = document.createElement("div")
    dialogContent.className = "bg-white rounded-lg p-6 max-w-md w-full mx-4"

    dialogContent.innerHTML = `
      <h3 class="text-lg font-semibold mb-4">Insert YouTube Video</h3>
      <form class="youtube-form space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">YouTube URL or Video ID</label>
          <input type="text" placeholder="https://www.youtube.com/watch?v=dQw4w9WgXcQ or dQw4w9WgXcQ" class="youtube-url-input input input-bordered text-sm w-full px-3 py-2 rounded border border-gray-300 focus:ring-sky-500" />
          <p class="text-xs text-gray-500 mt-1">Paste the full URL or just the video ID</p>
        </div>
        <div class="flex gap-2 justify-end">
          <button type="button" class="cancel-btn btn btn-primary text-sm px-4 py-2 rounded border border-gray-300 hover:bg-gray-50">Cancel</button>
          <button type="submit" class="confirm-btn btn btn-primary text-sm px-4 py-2 rounded bg-gray-950 hover:bg-gray-700 flex items-center transition cursor-pointer">
            <span class="material-icons text-white items-center text-base! mr-2 -ml-1">check_circle</span>
            <span class="text-white">Insert</span>
          </button>
        </div>
      </form>
    `

    dialog.appendChild(dialogContent)
    document.body.appendChild(dialog)

    const form = dialogContent.querySelector(".youtube-form")
    const urlInput = dialogContent.querySelector(".youtube-url-input")
    const cancelBtn = dialogContent.querySelector(".cancel-btn")

    const closeDialog = () => dialog.remove()

    const handleSubmit = (e) => {
      e.preventDefault()
      const input = urlInput.value.trim()
      if (input) {
        const videoID = this.extractYouTubeID(input)
        if (videoID) {
          this.editor.dispatchCommand(INSERT_YOUTUBE_COMMAND, videoID)
          closeDialog()
        } else {
          alert("Invalid YouTube URL or video ID")
        }
      } else {
        alert("Please enter a YouTube URL or video ID")
      }
    }

    form.addEventListener("submit", handleSubmit)
    cancelBtn.addEventListener("click", closeDialog)
    dialog.addEventListener("click", (e) => {
      if (e.target === dialog) closeDialog()
    })

    urlInput.focus()
  }

  showVideoDialog() {
    const dialog = document.createElement("div")
    dialog.className =
      "fixed inset-0 bg-gray-950/50 flex items-center justify-center z-80"

    const dialogContent = document.createElement("div")
    dialogContent.className = "bg-white rounded-lg p-6 max-w-md w-full mx-4"

    dialogContent.innerHTML = `
      <h3 class="text-lg font-semibold mb-4">Upload Video</h3>
      <form class="video-form">
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Select Video File (mp4, webm, mov - max 30MB)
          </label>
          <input type="file" accept="video/mp4,video/webm,video/quicktime" class="video-file-input w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" required />
        </div>
        <div class="flex justify-end gap-2">
          <button type="button" class="cancel-btn px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded hover:bg-gray-200">
            Cancel
          </button>
          <button type="submit" class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded hover:bg-blue-700">
            Upload
          </button>
        </div>
      </form>
    `

    dialog.appendChild(dialogContent)
    document.body.appendChild(dialog)

    const form = dialogContent.querySelector(".video-form")
    const fileInput = dialogContent.querySelector(".video-file-input")
    const cancelBtn = dialogContent.querySelector(".cancel-btn")

    const closeDialog = () => dialog.remove()

    const handleSubmit = async (e) => {
      e.preventDefault()
      const file = fileInput.files[0]

      if (file) {
        this.editor.dispatchCommand(INSERT_VIDEO_COMMAND, { file })
        closeDialog()
      } else {
        alert("Please select a video file")
      }
    }

    fileInput.focus()

    form.addEventListener("submit", handleSubmit)
    cancelBtn.addEventListener("click", closeDialog)
    dialog.addEventListener("click", (e) => {
      if (e.target === dialog) closeDialog()
    })
  }

  extractYouTubeID(input) {
    if (/^[a-zA-Z0-9_-]{11}$/.test(input)) {
      return input
    }

    const patterns = [
      /(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/,
      /youtube\.com\/embed\/([a-zA-Z0-9_-]{11})/,
      /youtube\.com\/v\/([a-zA-Z0-9_-]{11})/,
    ]

    for (const pattern of patterns) {
      const match = input.match(pattern)
      if (match && match[1]) {
        return match[1]
      }
    }

    return null
  }

  insertQuote() {
    this.ensureSelection()

    this.editor.update(() => {
      const selection = $getSelection()
      if (selection) {
        $setBlocksType(selection, () => $createQuoteNode())
      }
    })
  }

  insertCode() {
    this.ensureSelection()

    this.editor.update(() => {
      const selection = $getSelection()
      if (selection) {
        $setBlocksType(selection, () => $createCodeNode())
      }
    })
  }

  loadContent() {
    if (this.contentValue && this.contentValue !== "{}") {
      try {
        const content =
          typeof this.contentValue === "string"
            ? JSON.parse(this.contentValue)
            : this.contentValue

        // Fix legacy content: wrap loose text nodes in paragraphs
        // Lexical requires only element nodes (paragraph, heading, image) at root level
        if (content.root && content.root.children) {
          content.root = this.cleanSkeleton(content.root)
          content.root.children = this.flattenContent(content.root.children)
          content.root.children = this.wrapTextNodesInParagraphs(content.root.children)
        }

        const editorState = this.editor.parseEditorState(content)

        // Only update input if it exists (edit mode)
        if (this.hasInputTarget) {
          this.inputTarget.value = JSON.stringify(editorState.toJSON())
        }
        this.editor.setEditorState(editorState)
      } catch (error) {
        console.error("Failed to load content:", error)
      }
    }
  }

  // Wrap loose text nodes in paragraph nodes to fix legacy migrated content
  // Lexical requires only element/decorator nodes at root level
  wrapTextNodesInParagraphs(nodes) {
    if (!Array.isArray(nodes)) return nodes

    const result = []
    let textBuffer = []

    nodes.forEach(node => {
      if (node.type === 'text') {
        // Collect text nodes
        textBuffer.push(node)
      } else {
        // Before adding element node, flush any buffered text nodes
        if (textBuffer.length > 0) {
          result.push({
            type: 'paragraph',
            format: '',
            indent: 0,
            version: 1,
            direction: null,
            children: textBuffer,
            textStyle: '',
            textFormat: 0
          })
          textBuffer = []
        }
        result.push(node)
      }
    })

    // Flush any remaining text nodes
    if (textBuffer.length > 0) {
      result.push({
        type: 'paragraph',
        format: '',
        indent: 0,
        version: 1,
        direction: null,
        children: textBuffer,
        textStyle: '',
        textFormat: 0
      })
    }

    return result
  }

  cleanSkeleton(node) {
    if (node.type === 'skeleton') return false
    if (node.type === 'text' && ['', null, undefined].includes(node.format)) {
      // Lexical doesn't accept null/undefined/empty string format for text nodes
      // Text with invalid format can't be styled properly in the editor
      node.format = 0
    }

    if (node.children && Array.isArray(node.children)) {
      node.children = node.children
        .map(child => this.cleanSkeleton(child))
        .filter(child => child !== false)
    }

    return node
  }

  shouldBeAtRoot(nodeType) {
    return nodeType === 'image' || nodeType === 'youtube' || nodeType === 'video'
  }

  isEmptyInline(node) {
    if (!node) return true
    if (node.type === 'text') {
      const txt = node.text || ''
      return txt.trim().length === 0
    }
    if (node.type === 'link' || node.type === 'autolink') {
      if (!node.children || node.children.length === 0) return true
      return node.children.every(child => this.isEmptyInline(child))
    }
    return false
  }

  flattenContent(nodes) {
    if (!Array.isArray(nodes)) return nodes

    const result = []

    nodes.forEach(node => {
      if (node.type === 'paragraph' && node.children) {
        let inlineBuffer = []

        node.children.forEach(child => {
          if (this.shouldBeAtRoot(child.type)) {
            if (inlineBuffer.length > 0) {
              const filtered = inlineBuffer.filter(c => !this.isEmptyInline(c))
              if (filtered.length > 0) {
                result.push({
                  ...node,
                  children: filtered
                })
              }
              inlineBuffer = []
            }
            result.push(child)
          } else if (child.type === 'paragraph' && child.children) {
            const filtered = child.children.filter(c => !this.isEmptyInline(c))
            inlineBuffer.push(...filtered)
          } else if (child.type === 'list' && child.children) {
            const processedList = this.processListNode(child)

            if (processedList.decorators.length > 0) {
              const filtered = inlineBuffer.filter(c => !this.isEmptyInline(c))
              if (filtered.length > 0) {
                result.push({
                  ...node,
                  children: filtered
                })
                inlineBuffer = []
              }
              processedList.decorators.forEach(decorator => result.push(decorator))
            }

            if (processedList.list) {
              // filter out empty inline nodes inside list wrapper
              processedList.list.children = processedList.list.children.map(item => {
                if (item && item.children) {
                  item.children = item.children.filter(c => !this.isEmptyInline(c))
                }
                return item
              }).filter(i => {
                return !(i && i.children && i.children.length === 0)
              })
              if (processedList.list.children.length > 0) {
                inlineBuffer.push(processedList.list)
              }
            }
          } else {
            if (!this.isEmptyInline(child)) inlineBuffer.push(child)
          }
        })

        const finalFiltered = inlineBuffer.filter(c => !this.isEmptyInline(c))
        if (finalFiltered.length > 0) {
          result.push({
            ...node,
            children: finalFiltered
          })
        }
      } else if (node.type === 'list' && node.children) {
        const processedList = this.processListNode(node)
        processedList.decorators.forEach(decorator => result.push(decorator))
        if (processedList.list) {
          result.push(processedList.list)
        }
      } else {
        result.push(node)
      }
    })

    return result
  }

  processListNode(listNode) {
    const decorators = []
    const processedItems = []

    listNode.children.forEach(listItem => {
      if (listItem.type === 'listitem' && listItem.children) {
        const keptChildren = []

        listItem.children.forEach(child => {
          if (this.shouldBeAtRoot(child.type)) {
            decorators.push(child)
          } else if (child.type === 'paragraph' && child.children) {
            const nestedResult = this.flattenContent([child])
            nestedResult.forEach(item => {
              if (this.shouldBeAtRoot(item.type)) {
                decorators.push(item)
              } else if (!this.isEmptyInline(item)) {
                keptChildren.push(item)
              }
            })
          } else if (child.type === 'list' && child.children) {
            const nestedList = this.processListNode(child)
            decorators.push(...nestedList.decorators)
            if (nestedList.list) {
              // ensure nested list items are not empty
              nestedList.list.children = nestedList.list.children.map(i => {
                if (i && i.children) i.children = i.children.filter(c => !this.isEmptyInline(c))
                return i
              }).filter(i => !(i && i.children && i.children.length === 0))
              if (nestedList.list.children.length > 0) keptChildren.push(nestedList.list)
            }
          } else {
            if (!this.isEmptyInline(child)) keptChildren.push(child)
          }
        })

        if (keptChildren.length > 0) {
          processedItems.push({
            ...listItem,
            children: keptChildren
          })
        }
      } else {
        processedItems.push(listItem)
      }
    })

    return {
      decorators,
      list: processedItems.length > 0 ? { ...listNode, children: processedItems } : null
    }
  }

  setupEventListeners() {
    // Only register update listener if we have an input target (edit mode)
    if (this.hasInputTarget) {
      this.unregisterListener = this.editor.registerUpdateListener(
        ({ editorState }) => {
          const json = editorState.toJSON()
          this.inputTarget.value = JSON.stringify(json)

          // Handle video UI
          try {
            const selectedVideoNodes = editorState.read(() => {
              const selection = $getSelection()
              if (!selection || !$isRangeSelection(selection)) return []

              return selection.getNodes().filter(node => node instanceof VideoNode)
            })
            const nonSelectedVideoNodes = editorState.read(() => {
              const root = $getRoot()
              return this._fetchAllChildren(root, [], VideoNode).filter(node => !selectedVideoNodes.includes(node))
            })

            selectedVideoNodes.forEach(videoNode => {
              videoNode.setSelectedUI()
            })
            nonSelectedVideoNodes.forEach(videoNode => {
              videoNode.setUnselectedUI()
            })
          } catch (error) {
            console.error("Error updating video node UI:", error)
          }

          // Handle Youtube UI
          try {
            const selectedYoutubeNodes = editorState.read(() => {
              const selection = $getSelection()
              if (!selection || !$isRangeSelection(selection)) return []

              return selection.getNodes().filter(node => node instanceof YouTubeNode)
            })
            const nonSelectedYoutubeNodes = editorState.read(() => {
              const root = $getRoot()
              return this._fetchAllChildren(root, [], YouTubeNode).filter(node => !selectedYoutubeNodes.includes(node))
            })

            selectedYoutubeNodes.forEach(youtubeNode => {
              youtubeNode.setSelectedUI()
            })
            nonSelectedYoutubeNodes.forEach(youtubeNode => {
              youtubeNode.setUnselectedUI()
            })
          } catch (error) {
            console.error("Error updating video node UI:", error)
          }

          this.dispatch("change", { detail: { content: json } })
        },
      )

      this.editorTarget.addEventListener("blur", () => {
        this.dispatch("blur", { detail: { content: this.getEditorContent() } })
      })
    }
  }

  _fetchAllChildren(node, allChildren, typeFilter = null) {
    if (!("getChildren" in node)) return allChildren

    const children = node.getChildren()
    children.forEach(child => {
      if (!typeFilter || child instanceof typeFilter) {
        allChildren.push(child)
      }
      this._fetchAllChildren(child, allChildren, typeFilter)
    })

    return allChildren
  }

  ensureSelection() {
    this.editorTarget.focus()

    this.editor.update(() => {
      const selection = $getSelection()

      if (!selection || !$isRangeSelection(selection)) {
        const root = $getRoot()
        const children = root.getChildren()

        if (children.length === 0) {
          const paragraph = $createParagraphNode()
          root.append(paragraph)
          paragraph.select()
        } else {
          const lastChild = children[children.length - 1]
          lastChild.selectEnd()
        }
      }
    })
  }

  showToast(message, type = "error") {
    document.dispatchEvent(
      new CustomEvent("toast:show", {
        detail: { message, type },
      }),
    )
  }

  getEditorContent() {
    return this.editor.getEditorState().toJSON()
  }

  isEmpty() {
    let empty = true
    this.editor.getEditorState().read(() => {
      const root = $getRoot()
      const text = root.getTextContent().trim()

      if (text.length > 0) {
        empty = false
        return
      }

      const hasDecoratorNodes = [...root.getChildren()].some(node => this._containDecoratorNodes(node))

      empty = !hasDecoratorNodes
    })
    return empty
  }

  _containDecoratorNodes(node) {
    if (node instanceof DecoratorNode) {
      return true
    }
    const children = node.getChildren()
    if (children.length > 0) {
      return children.some(child => this._containDecoratorNodes(child))
    }
    return false
  }

  disconnect() {
    if (this.unregisterListener) {
      this.unregisterListener()
    }
    if (this.editor) {
      const existingToolbar = this.editorTarget.previousElementSibling
      if (
        existingToolbar &&
        existingToolbar.getAttribute("role") === "toolbar"
      ) {
        existingToolbar.remove()
      }

      if (this.editableValue) {
        const existingToolbar = this.editorTarget.previousElementSibling
        if (
          existingToolbar &&
          existingToolbar.getAttribute("role") === "toolbar"
        ) {
          existingToolbar.remove()
        }
      }
      this.editor.setRootElement(null)
    }
    if (this.pasteHandler) {
      this.pasteHandler = null
    }
  }
}
