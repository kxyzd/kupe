module Guu
  class Interpreter
    Instruction = Struct.new(:keyword, :arity, :block)

    Instructions = Struct.new(:instructions) do
      def [](name, &block)
        instructions[name] = Instruction.new(
          name, block.arity, block
        )
      end

      def match(keyword)
        Maybe(instructions[keyword])
      end
    end

    def initialize(program, main: 'main')
      @program = program
      @main_subproc = main
      @envs = {}

      @instructions = Instructions.new({})

      @instructions['print'] do |token|
        puts to_guu_obj(token)
      end

      @instructions['set'] do |name, value|
        @envs[name.value] = to_guu_obj(value)
      end

      @instructions['call'] do |name|
        if subproc = @program[name.value]
          exec_(subproc)
        else
          Guu::SemanticError.fail(
            "Нету такой процедуры как `#{name.value}`!",
            line: name.line
          )
        end
      end
    end

    def exec
      if subproc = @program[@main_subproc]
        exec_(subproc)
      else
        Guu::SemanticError.fail(
          "Нету указанной точки входа `#{@main_subproc}`."
        )
      end
    end

    private

    def exec_(subproc)
      subproc.iter
      while (token = subproc.next).is_a? Some
        token = token.value!

        if (instr = @instructions.match(token.value)).is_a? Some
          instr = instr.value!
        else
          Guu::SemanticError.fail(
            "Нету такой инструкции как `#{token.value}`!",
            line: token.line
          )
        end

        if (args = instr.arity.times.map { subproc.next }).all? Some
          instr.block.call(*args.map(&:value!))
        else
          Guu::SemanticError.fail(
            "Недостаточно аргументов инструкции `#{instr.name}`!",
            line: token.value!.value
          )
        end

      end
    end

    def to_guu_obj(_token)
      case string = _token.value
      when /\d+/
        string.to_i
      else
        if value = @envs[string]
          value
        else
          Guu::SemanticError.fail(
            "Не определена переменная `#{string}`!",
            line: _token.line
          )
        end
      end
    end
  end
end
