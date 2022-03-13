require 'forwardable'
require 'dry/monads'

include Dry::Monads[:maybe]

module Guu
  module Frontend
    Programm = Struct.new(:subprocs) do
      extend Forwardable
      def_delegators :subprocs, :[], :[]=
    end

    TokenStream = Struct.new(:tokens) do
      extend Forwardable

      def iter
        @iter = tokens.each
      end

      def next
        Some(@iter.next)
      rescue StopIteration
        None()
      end

      def_delegators :tokens, :<<
    end

    SubProc = Struct.new(:name, :body) do
      extend Forwardable

      def_delegators :body, :<<, :iter, :next
    end

    def self.parse(tokens, lines:)
      symbol_table = Guu::Semantic::SymbolTable.new([], [])
      guu_programm = Programm.new({})

      current_subproc_name = nil

      until tokens.empty?
        case (token = tokens.shift).value
        when 'sub'
          if (subproc_name = tokens.shift).value =~ /\A[a-zA-Z]+\z/
            current_subproc_name = SubProc.new(subproc_name.value, TokenStream.new([]))

            guu_programm[subproc_name.value] = current_subproc_name

            symbol_table.subproc_names << Guu::Semantic::SubProc.new(
              subproc_name.value,
              {
                line: subproc_name.line
              }
            )
          else
            Guu::SyntaxError.fail(
              "Имя процедуры должо содержать только [a-zA-Z]!",
              line: token.line.pred,
              lines: lines
            )
          end
        when 'set'
          if (name_var = tokens.shift).value =~ /\A[a-zA-Z]+\z/
            if (value_var = tokens.shift).value =~ /\A([a-zA-Z]+|[0-9]+)\z/

              if current_subproc_name
                current_subproc_name << token
                current_subproc_name << name_var
                current_subproc_name << value_var
              else
                Guu::SyntaxError.fail(
                  "Инструкция установки значения не может быть вне процедуры!",
                  line: token.line,
                  lines: lines
                )
              end

              symbol_table.variable_names << Guu::Semantic::Variable.new(
                name_var.value,
                Guu::Semantic::Obj.from(value_var.value),
                {
                  line: token.line
                }
              )
            else
              Guu::SyntaxError.fail(
                "Значение могут состоять только из ([a-zA-Z]+|[0-9]+)!",
                line: token.line.succ,
                lines: lines
              )
            end
          else
            Guu::SyntaxError.fail(
              "Имя переменной может содержать только [a-zA-Z]!",
              line: token.line,
              lines: lines
            )
          end
        else
          if current_subproc_name.nil?
            Guu::SyntaxError.fail(
              "Инструкции не могут быть вне процедур!",
              line: token.line.pred,
              lines: lines
            )
          else
            current_subproc_name << token
          end
        end
      end

      if current_subproc_name and not $guu_syntax_error
        [symbol_table, guu_programm]
      else
        Guu::SyntaxError.fail(
          "Ошибка.",
          code: 1
        )
      end
    end

    def self.tokenize(source)
      case source
      when Array
        [source, tokenize_lines(source)]
      when String
        lines = source.split("\n")
        [lines, tokenize_lines(lines)]
      else
        raise SyntaxError, 'Метод `tokenize` принимает только Array или String!!!'
      end
    end

    private

    def self.tokenize_lines(lines)
      lines.zip(1..).each_with_object([]) do |(line, number), tokens|
        tokens.concat line.split.map { Guu::Tokens::Token.new(_1, number) } 
      end
    end
  end
end
