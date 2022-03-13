module Guu
  class PhasesBuilder
    def initialize(&block)
      @phases = []
      instance_eval(&block)
    end

    def bind(name, &block)
      @phases << [name, block]
    end

    def run(input)
      @phases.reduce(input) do |argument, (_name, block)|
        block.call(argument)
      rescue StandardError => e
        self.fail(_name, e)
      end
    end

    private

    def fail(name, e, code: 1)
      puts "Ошибка на этапе. #{name}\n\t#{e}"
      exit code
    end
  end
end
