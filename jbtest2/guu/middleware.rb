module Guu
  class Middelware
    def initialize
      @middelwares = []
    end

    def call(symbol_table, programm)
      @middelwares.reduce([symbol_table, programm], &:call)
    end
  end
end
