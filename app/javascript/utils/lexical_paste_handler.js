import { $createImageNode } from "../nodes/image_node"
import { $createYouTubeNode } from "../nodes/youtube_node"
import { $createParagraphNode, $createTextNode, $getRoot, $getSelection, $isRangeSelection } from "lexical"

const YOUTUBE_URL_REGEX = /(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})(?:[?&]si=[^&\s]*)?/gi

/**
 * Handles paste events for the Lexical editor, supporting images from HTML and YouTube URLs.
 *
 * Supported paste formats:
 * - Images: Extracts <img> tags from pasted HTML and inserts them as image nodes.
 * - YouTube URLs: Detects pasted YouTube links and inserts them as YouTube nodes.
 *
 * Integration:
 * - Receives a Lexical editor instance via the constructor.
 * - Uses editor.update() to insert nodes based on the paste content.
 *
 * Usage:
 *   const handler = new LexicalPasteHandler(editor);
 *   editor.registerCommand(PASTE_COMMAND, (event) => handler.handlePaste(event), COMMAND_PRIORITY_NORMAL);
 */
export class LexicalPasteHandler {
  constructor(editor) {
    this.editor = editor
  }

  handlePaste(event) {
    const clipboardData = event.clipboardData || window.clipboardData
    const htmlData = clipboardData.getData("text/html")
    const pastedText = clipboardData.getData("text/plain")

    if (htmlData && this.handleHtmlPaste(event, htmlData)) {
      return true
    }

    if (pastedText && this.handleYouTubePaste(event, pastedText)) {
      return true
    }

    return false
  }

  handleHtmlPaste(event, htmlData) {
    const parser = new DOMParser()
    const doc = parser.parseFromString(htmlData, "text/html")
    const bodyContent = doc.body

    if (!bodyContent || !bodyContent.querySelector("img")) {
      return false
    }

    event.preventDefault()

    this.editor.update(() => {
      const selection = $getSelection()
      const nodesToInsert = this.extractNodesFromHtml(bodyContent)

      if (nodesToInsert.length > 0) {
        this.insertNodes(selection, nodesToInsert)
      }
    })

    return true
  }

  extractNodesFromHtml(bodyContent) {
    const nodesToInsert = []

    bodyContent.childNodes.forEach(node => {
      const result = this.processNode(node)
      if (result) {
        if (Array.isArray(result)) {
          nodesToInsert.push(...result)
        } else {
          nodesToInsert.push(result)
        }
      }
    })

    return nodesToInsert
  }

  processNode(node) {
    if (node.nodeType === Node.TEXT_NODE) {
      return this.processTextNode(node)
    } else if (node.nodeType === Node.ELEMENT_NODE) {
      return this.processElementNode(node)
    }
    return null
  }

  processTextNode(node) {
    const text = node.textContent
    if (text.trim()) {
      return { type: 'text', content: text }
    }
    return null
  }

  processElementNode(node) {
    if (node.tagName === 'IMG') {
      return this.processImageNode(node)
    } else if (node.tagName === 'P' || node.tagName === 'DIV') {
      return this.processBlockNode(node)
    } else {
      return this.processInlineNode(node)
    }
  }

  processImageNode(node) {
    const src = node.src
    const altText = node.alt || "Pasted image"
    if (src) {
      return { type: 'image', src, altText }
    }
    return null
  }

  processBlockNode(node) {
    const childResults = this.processChildNodes(node)
    return childResults.length > 0 ? childResults : null
  }

  processInlineNode(node) {
    return this.processChildNodes(node)
  }

  processChildNodes(node) {
    const childResults = []
    node.childNodes.forEach(child => {
      const result = this.processNode(child)
      if (result) {
        if (Array.isArray(result)) {
          childResults.push(...result)
        } else {
          childResults.push(result)
        }
      }
    })
    return childResults
  }

  insertNodes(selection, nodesToInsert) {
    if ($isRangeSelection(selection)) {
      this.insertNodesInSelection(selection, nodesToInsert)
    } else {
      this.appendNodesToRoot(nodesToInsert)
    }
  }

  insertNodesInSelection(selection, nodesToInsert) {
    nodesToInsert.forEach(item => {
      if (item.type === 'image') {
        const imageNode = $createImageNode({
          src: item.src,
          altText: item.altText,
          width: "inherit",
          height: "inherit",
        })
        selection.insertNodes([imageNode])
      } else if (item.type === 'text') {
        selection.insertText(item.content)
      }
    })
  }

  appendNodesToRoot(nodesToInsert) {
    const root = $getRoot()
    nodesToInsert.forEach(item => {
      if (item.type === 'image') {
        const imageNode = $createImageNode({
          src: item.src,
          altText: item.altText,
          width: "inherit",
          height: "inherit",
        })
        root.append(imageNode)
      } else if (item.type === 'text') {
        const paragraph = $createParagraphNode()
        paragraph.append($createTextNode(item.content))
        root.append(paragraph)
      }
    })
  }

  handleYouTubePaste(event, pastedText) {
    const matches = [...pastedText.matchAll(YOUTUBE_URL_REGEX)]

    if (matches.length === 0) {
      return false
    }

    event.preventDefault()

    this.editor.update(() => {
      const selection = $getSelection()
      if ($isRangeSelection(selection)) {
        this.insertYouTubeVideos(selection, pastedText, matches)
      }
    })

    return true
  }

  insertYouTubeVideos(selection, pastedText, matches) {
    let textToInsert = pastedText

    matches.forEach((match) => {
      const videoID = match[1]
      const fullMatch = match[0]

      const parts = textToInsert.split(fullMatch)
      if (parts[0]) {
        selection.insertText(parts[0])
      }

      const youtubeNode = $createYouTubeNode(videoID)
      selection.insertNodes([youtubeNode])

      textToInsert = parts.slice(1).join(fullMatch)
    })

    if (textToInsert) {
      selection.insertText(textToInsert)
    }
  }
}
