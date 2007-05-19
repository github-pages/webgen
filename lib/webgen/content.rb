require 'yaml'

# A single block within a page object. The content of the block can be rendered using the #render method.
class Block

  # The name of the block.
  attr_reader :name

  # The content of the block.
  attr_reader :content

  # The options set specifically for this block (includes, for example, the +pipeline+).
  attr_reader :options

  # Creates a new block with the name +name+ and the given +content+ and +options+.
  def initialize( name, content, options )
    @name, @content, @options = name, content, options
  end

  # Renders the block using the provided +context+. The +context+ hash needs to provide at least the
  # following keys
  #
  # <tt>:chain</tt>::      the node chain
  # <tt>:processors</tt>:: the list of all useable content processors
  #
  # Uses the content processors specified in the +pipeline+ key of the +options+ attribute to do the
  # rendering.
  def render( context )
    temp = content
    @options['pipeline'].to_s.split(/;/).each do |processor|
      raise "No such content processor available: #{converter}" unless context[:processors].has_key?( processor )
      temp = context[:processors][processor].process( temp, context, @options )
    end
    temp
  end

end


# A Page object wraps a meta information hash and an array of blocks (class Block). It is normally
# generated from a file or a string in WebPage Format.
class Page

  # The contents of the meta information block.
  attr_reader :meta_info

  # Creates a new Page object with the meta information provided in +meta_info+. You can either
  # provide the blocks array via the +blocks+ parameter or you can specify a block which gets
  # invoked the first time the blocks array is accessed.
  def initialize( meta_info = {}, blocks = nil, &block_proc )
    @meta_info = meta_info
    @blocks = blocks
    @blocks_creation_proc = block_proc
  end

  # Returns the array of blocks for the page.
  def blocks
    @blocks = @blocks_creation_proc.call if @blocks.nil? && !@blocks_creation_proc.nil?
    @blocks
  end

end


# Raised during parsing of data in WebPage Format if the data is invalid.
class WebPageFormatError < RuntimeError; end


# Provides methods for creating a Page object from data in WebPage Format
class WebPageFormat

  RE_META_INFO_START = /\A---(?:\n|\r|\r\n)/m
  RE_META_INFO = /\A---(?:\n|\r|\r\n).*?(?:\n|\r|\r\n)(?=---.*?(?:\n|\r|\r\n))/m

  # Creates a new Page object from the file +file+ in WebPage Format. The +meta_info+ parameter can
  # be used to provide default meta information.
  def self.create_page_from_file( file, meta_info = {} )
    if File.size( file ) <= 1024
      create_from_data( File.read( file ), meta_info )
    else
      file_pos = 0
      File.open( file, 'r' ) do |fd|
        data = fd.read( 1024 )
        if data =~ RE_META_INFO_START
          data << fd.read(1024) while !(md = RE_META_INFO.match( data )) && !fd.eof?
          raise( PageInvalid, 'Invalid structure of meta information part') if md.nil?
          meta_info = meta_info.merge( parse_meta_info( normalize_eol( md[0] ) ) )
          file_pos = md[0].length
        end
      end
      Page.new( meta_info ) do
        blocks = ''
        File.open( file, 'r' ) do |fd|
          fd.seek( file_pos )
          blocks = parse_blocks( normalize_eol( fd.read ), meta_info )
        end
        blocks
      end
    end
  end

  # Parses the given string +data+ in WebPage Format and initializes a new Page object with the
  # information. The +meta_info+ parameter can be used to provide default meta information.
  def self.create_page_from_data( data, meta_info = {} )
    md = /(#{RE_META_INFO})?(.*)/m.match( normalize_eol( data ) )
    raise( PageInvalid, 'Invalid structure of meta information part') if md[1].nil? && data =~ RE_META_INFO_START
    meta_info = meta_info.merge( parse_meta_info( md[1] ) ) if !md[1].nil?
    blocks = parse_blocks( md[2] || '', meta_info )
    Page.new( meta_info, blocks )
  end

  #######
  private
  #######

  def self.normalize_eol( data )
    data.gsub( /\r\n?/, "\n" )
  end

  def self.parse_meta_info( data )
    begin
      meta_info = YAML::load( data )
      raise( PageInvalid, 'Invalid structure of meta information part') unless meta_info.kind_of?( Hash )
    rescue ArgumentError => e
      raise PageInvalid, e.message
    end
    meta_info
  end

  #TODO enable parsing of --- name, format:data, test:data, key:value
  #blocks:
  #  default:           # default values for all blocks
  #    format: textile
  #    pipeline: doit;haus;end
  #  entries:           # indiv entries for blocks, use ~ (nil) to not set name or options
  #    - [name, {format:textile, pipeline:doit}]
  #
  # test: "--- asdfasdf, asdfasd:asdfasdf,adfasdf\n" -> invalid "--- test\nasdf\n----" valid
  # Handle case where meta info is invalid "---\nasdfasdfsdf" (no more \n---\n)!
  def self.parse_blocks( data, meta_info )
    scanned = data.scan( /(?:(?:^--- *(?:(\w+) *((?:, *\w+:[^\s,]+ *)*))?$)|\A)(.*?)(?:(?=^--- *(?:(?:\w+) *(?:(?:, *\w+:[^\s,]+ *)*))?$)|\Z)/m )
    raise( PageInvalid, 'No content blocks specified' ) if scanned.length == 0

    blocks = {}
    scanned.each_with_index do |block_data, index|
      name, options, content = *block_data
      raise( PageInvalid, "Found invalid blocks starting line" ) if content =~ /\A---/
      name = name || (meta_info['blocks']['entries'][index][0] rescue nil) || (index == 0 ? 'content' : 'block' + (index + 1).to_s)
      raise( PageInvalid, "Same name used for more than one block: #{name}" ) if blocks.has_key?( name )
      content ||= ''
      content.gsub!( /^(\\+)(---.*?)$/ ) {|m| "\\" * ($1.length / 2) + $2 }
      content.strip!
      options = (meta_info['blocks']['default'] rescue {}).
        merge( (meta_info['blocks']['entries'][index][1] rescue {}) ).
        merge( (!options.nil? && Hash[*options.scan(/(\w+):([^\s,]+)/).flatten]) || {} )
      blocks[name] = blocks[index+1] = Block.new( name, content, options )
    end
    blocks
  end

end
