# frozen_string_literal: true

class BlogProductLinkerService
  require 'ahocorasick'

  def initialize(blog)
    @blog = blog
    @linked_products = Set.new
  end

  def link_products
    content = begin
      if @blog.content.is_a?(String)
        JSON.parse(@blog.content)
      else
        @blog.content
      end
    rescue JSON::ParserError
      nil
    end

    return unless content

    plain_text = extract_text_from_lexical(content['root'])
    return if plain_text.blank?

    products = load_active_products
    return if products.empty?

    automaton = build_automaton(products)
    matches = match_data(automaton, plain_text, products)
    return if matches.empty?

    content = content.deep_dup
    process_node(content['root'], matches)

    @blog.update_column(:content, content)
    update_blog_products(@linked_products.to_a)
    Product.where(id: @linked_products.to_a)
  end

  private

  def match_data(matcher, original_text, products)
    matches = matcher.lookup(original_text.downcase).uniq
    products_by_name = products.index_by { |p| p.name.strip.downcase }

    matches.map do |match|
      product = products_by_name[match]
      next unless product
      {
        match_content: match,
        product:,
        length: match.length
      }
    end.compact
  end

  def extract_text_from_lexical(node)
    return '' unless node.is_a?(Hash)

    text = ''
    text += node['text'] + ' ' if node['type'] == 'text' && node['text'].present?

    if node['children'].is_a?(Array)
      node['children'].each { |child| text += extract_text_from_lexical(child) }
    end

    text
  end

  def load_active_products
    Product.where(status: 'active').where.not(name: [nil, '']).select(:id, :name, :slug)
  end

  def build_automaton(products)
    automaton = AhoC::Trie.new
    products.sort_by { |p| -p.name.length }.each do |product|
      automaton.add(product.name.strip.downcase)
    end
    automaton.build
    automaton
  end

  def process_node(node, matches)
    return unless node.is_a?(Hash)
    return if node['type'] == 'link'

    if node['children'].is_a?(Array)
      new_children = []
      node['children'].each do |child|
        if child['type'] == 'text'
          new_children.concat(process_text_node(child, matches))
        else
          process_node(child, matches)
          new_children << child
        end
      end
      node['children'] = new_children
    end
  end

  def process_text_node(text_node, matches)
    text = text_node['text']
    return [text_node] if text.blank?

    normalized_text = text.downcase
    applicable_matches = matches.select do |m|
      normalized_text.include?(m[:match_content])
    end

    return [text_node] if applicable_matches.empty?

    match = applicable_matches.max_by { |m| m[:length] }
    product = match[:product]
    pattern = /#{Regexp.escape(match[:match_content])}/i
    match_data = text.match(pattern)

    return [text_node] unless match_data

    @linked_products.add(product.id)

    start_pos = match_data.begin(0)
    end_pos = match_data.end(0)
    matched_text = match_data[0]

    if start_pos == 0 && end_pos == text.length
      return [create_link_node(product, matched_text, text_node)]
    end

    result = []
    result << create_text_node(text[0...start_pos], text_node) if start_pos > 0
    result << create_link_node(product, matched_text, text_node)
    result << create_text_node(text[end_pos..], text_node) if end_pos < text.length
    result.compact
  end

  def create_link_node(product, matched_text, original_node)
    {
      'rel' => nil,
      'url' => "/#{product.slug}",
      'type' => 'link',
      'title' => nil,
      'format' => original_node['format'] || '',
      'indent' => 0,
      'target' => nil,
      'version' => 1,
      'children' => [create_text_node(matched_text, original_node)],
      'direction' => nil
    }
  end

  def create_text_node(text, original_node)
    return nil if text.blank?

    {
      'mode' => original_node['mode'] || 'normal',
      'text' => text,
      'type' => 'text',
      'style' => original_node['style'] || '',
      'detail' => original_node['detail'] || 0,
      'format' => original_node['format'] || 0,
      'version' => 1
    }
  end

  def update_blog_products(product_ids)
    return if product_ids.empty?

    Blog.transaction do
      current_product_ids = @blog.product_ids
      combined_product_ids = (current_product_ids + product_ids).uniq
      @blog.product_ids = combined_product_ids
    end
  end
end
