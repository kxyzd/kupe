require 'pry'
require 'forwardable'

class Guu
  Token = Struct.new(:value, :line)

  TokenStream = Struct.new(:tokens) do
    extend Forwardable

    def next(attr = nil)
      self.tokens.shift.then do |token|
        if attr and attr.kind_of? Symbol then token.send attr
        else token end
      end
    end

    def dup
      self.class.new self.tokens.dup
    end

    def take!(n)
      n.times.map { tokens.shift }
    end

    def_delegators :tokens, :empty?, :<<, :first
    alias peek first
  end

  GuuSubProc = Struct.new(:name, :line, :body) do
    extend Forwardable

    @@subprocs = {}

    def self.create(name_token)
      @@subprocs[name_token.value] = self.new(
        name_token.value,
        name_token.line,
        TokenStream.new([])
      )
    end

    def self.[](name)
      if subproc = @@subprocs[name]
        subproc
      else
        raise GuuError.new "Неизвестная процедура '#{name}'!"
      end
    end

    def_delegators :body, :empty?, :next, :<<
  end

  GuuObjects = Struct.new(:vars) do
    def get(value)
      case value
      when /\d+/
        value.to_i
      when /\w+/
        raise GuuError.new "Неизвестная переменная '#{value}'" \
          unless v = self.vars[value]
        v
      else
        raise GuuError.new "Неизвестный Guu-объект #{value.inspect}"
      end
    end

    def set(name, value)
      self.vars[name] = value
    end
  end

  Debugger = Struct.new(:opts) do
    def call(_)
      raise GuuError.new "Должен быть реализован метод 'call'!!!"
    end

    def catch(_)
      raise GuuError.new "Должен быть реализован метод 'catch'!!!"
    end
  end

  class GuuError < StandardError; end

  def initialize(main: 'main')
    @variables, @subprocs = {}, {}
    @guu_objs = GuuObjects.new @variables
    @stacktrace = []
    @main_subproc = main
  end

  def exec(source, pry: false)
    @source = source
    tokens = TokenStream.new tokenize source
    preinterpreter tokens
    
    @stacktrace << (subproc = GuuSubProc[@main_subproc])
    interpreter subproc

    binding.pry if pry
  end

  def debug(debugger = nil, pry: false, &block)
    return unless (dbg = debugger or block)
    @debughook_flag = true
    @debughook = case dbg
                 when Class then dbg.new
                 when Proc  then dbg
                 else raise TypeError ; end
    binding.pry if pry
  end

  private

  def debughook(opts)
    opts[:guu_objs] = @guu_objs
    opts[:guu_subproc] = GuuSubProc
    opts[:source] = @source
    opts[:stacktrace] = @stacktrace

    @debughook.call opts
  end

  def interpreter(subproc)
    tokens = subproc.body.dup
    until tokens.empty?

      debughook({
        subproc: subproc,
        tokens: tokens,
        token: tokens.peek
      }) if @debughook_flag
      
      begin
        case (token = tokens.next).value
        when 'set'
          name_var, value_var = tokens.take!(2).map!(&:value)
          @guu_objs.set(name_var, @guu_objs.get(value_var))
        when 'print'
          puts @guu_objs.get tokens.next :value
        when 'call'
          name_subproc = tokens.next :value
          subproc = GuuSubProc[name_subproc]
          @stacktrace << subproc
          interpreter subproc
        else
          raise GuuError.new \
            "Неизвестная инструкция '#{token.value}'" + 
              " на строке #{token.line}!"
        end
      rescue GuuError => e
        @debughook.catch e 
      end
    end
    @stacktrace.pop
  end

  def preinterpreter(tokens)
    until tokens.empty?
      case (token = tokens.next).value
      when 'sub'
        name_token = tokens.next
        current_subproc = GuuSubProc.create name_token
      else
        current_subproc << token
      end
    end
  end

  def tokenize(source)
    source.split(?\n).zip(1..).each_with_object([]) do |(line, i), tokens|
      tokens.concat line.split.map { Token.new(_1, i) }
    end
  end
end

class SimpleDebugger < Guu::Debugger
  require 'readline'

  def call(opts)
    return if @skip
    return if (t =@saved_stacktrace) and opts[:stacktrace] != t

    print_source(opts[:source], opts[:token].line.pred)

    loop do
      case input = Readline.readline("Hanter%Bugs::> ").strip
      when 'next', 'i'
        @saved_stacktrace = nil
        break
      when 'o'
        @saved_stacktrace = opts[:stacktrace].dup
        break
      when 'skip'
        @skip = true
        break
      when 'vars'
        pp opts[:guu_objs]
      when 'trace'
        opts[:stacktrace].zip(1..).each do |(subproc, i)|
          puts(" " * i + "=> #{subproc.name} on #{subproc.line} line")
        end
      end
    end
  end
  
  def print_source(source, curr_i)
    print "\n"
    source.split(?\n).each_with_index do |line, i|
      if curr_i == i
        puts "\t==> #{line}"
      else
        puts "\t  # #{line}"
      end
    end
    print "\n"
  end
end

##################################

guui = Guu.new

if ARGV[0] == 'debug'
  guui.debug SimpleDebugger
  namefile = ARGV[1]
else
  namefile = ARGV[0]
end

guui.exec File.read namefile
