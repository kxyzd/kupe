require_relative 'error'
require_relative 'frontend'
require_relative 'guui'
require_relative 'middleware'
require_relative 'phases'

module Guu
  FAIL_ALWAYS = false

  module Semantic
    SymbolTable = Struct.new(:subproc_names, :variable_names)
    Variable = Struct.new(:name, :value, :meta)
    SubProc = Struct.new(:name, :meta)

    Obj = Struct.new(:type, :value) do
      def self.from(string)
        case string
        when /\d+/
          Obj.new(:number, string)
        else
          Obj.new(:variable, string)
        end
      end
    end
  end

  module Tokens
    Token = Struct.new(:value, :line)
    Tokens = Array
  end
end
