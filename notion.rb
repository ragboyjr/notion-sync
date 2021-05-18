require 'faraday'
require 'faraday/middleware'
require 'json'

NOTION_API_KEY = %q()

class NotionAPI
    def initialize(token)
        @client = Faraday.new(
            url: 'https://api.notion.com/v1/',
            headers: {
                "Notion-Version" => '2021-05-13',
                "Authorization" => "Bearer #{token}"
            }
        ) { |f| f.response :logger, nil, {headers: false, bodies: true} }
    end

    def get_page(page_id)
        request { |c| c.get("pages/#{page_id}") }
    end

    def get_block_children(block_id)
        request { |c| c.get("blocks/#{block_id}/children") }
    end

    def append_block_children(block_id, blocks)
        request { |c| c.patch("blocks/#{block_id}/children", {children: blocks.map(&:to_h)}.to_json, {"Content-Type" => 'application/json'}) }
    end

    private

    def request(&block)
        JSON.parse!(block.call(@client).body)
    end
end

class NotionAPI::Block
    def initialize(data)
        @data = data
    end

    def self.from_type(type, data)
        new(data.merge({object: 'block', type: type}))
    end

    # children are not supported
    def self.paragraph(text, children = nil)
        from_type('paragraph', {paragraph: {text: wrap_to_rich_text(text)}})
    end

    def self.h1(text)
        heading(1, text)
    end

    def self.h2(text)
        heading(2, text)
    end

    def self.h3(text)
        heading(3, text)
    end

    def to_h
        @data
    end

    private

    def self.heading(num, text)
        key = "heading_#{num}"
        from_type(key, {key.to_sym => {text: wrap_to_rich_text(text)}})
    end

    def self.wrap_to_rich_text(text)
        Array(text).map(&NotionAPI::RichText.method(:wrap)).map(&:to_h)
    end
end

class NotionAPI::RichText
    def initialize(data)
        @data = data
    end

    def self.wrap(value)
        value.is_a?(self) ? value : self.text(value)
    end

    def self.text(value, &block)
        new({
            plain_text: value, 
            type: 'text', 
            annotations: AnnotationsBuilder.new.(&block),
            text: {content: value}
        })
    end
    
    def to_h
        @data
    end

    # @!method bold(value = true)
    #   @return [self]
    # @!method italic(value = true)
    #   @return [self]
    # @!method strikethrough(value = true)
    #   @return [self]
    # @!method underline(value = true)
    #   @return [self]
    # @!method code(value = true)
    #   @return [self]
    class AnnotationsBuilder
        def initialize
            @data = {
                color: "default",
            }
        end

        %i[bold italic strikethrough underline code].each do |name|
            define_method(name) do |value = true| 
                if value
                    @data[name] = value
                else 
                    @data.delete(name)
                end
                self
            end
        end

        %i[
            gray brown orange yellow green blue purple pink red gray_background brown_background orange_background 
            yellow_background green_background blue_background purple_background pink_background red_background
        ].each do |name|
            define_method(name) { color(name.to_s) }
        end

        def color(color)
            @data[:color] = color
            self
        end

        def call(&block)
            block.(self) if block
            @data
        end
    end

end


def main

end 


notion = NotionAPI.new(NOTION_API_KEY)
# pp notion.get_page('c1c8e6a2-a049-456d-abe5-a4b157e4457f')
# notion.get_block_children('c1c8e6a2-a049-456d-abe5-a4b157e4457f')

# p NotionAPI::Block.h1('Page H1').to_h
notion.append_block_children('c1c8e6a2-a049-456d-abe5-a4b157e4457f', [
    NotionAPI::Block.paragraph([
        NotionAPI::RichText.text('Page H1') { |a| a.italic.yellow },
        NotionAPI::RichText.text(' - 1') { |a| a.bold.red }
    ])
])

# p NotionAPI::RichText.text('hi') { |a| a.bold.italic.green_background }

