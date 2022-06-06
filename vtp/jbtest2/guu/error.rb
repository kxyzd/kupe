module Guu
  module SyntaxError
    def self.fail(_msg, line: '?', pos: '?', lines: nil, code: nil)
      $guu_syntax_error = true
      puts "Синтаксическая ошибка: #{_msg}. Смотрите строку #{line}:#{pos}\n" +
           (lines ? "\t#{line}: #{lines[line]}" : '')
      exit code if code
      exit 1 if Guu::FAIL_ALWAYS
    end
  end

  module SemanticError
    def self.fail(_msg, line: '?', pos: '?', lines: nil, code: 1)
      puts "Семантическая ошибка: #{_msg}. Смотрите строку #{line}:#{pos}\n" +
           (lines ? "\t#{line}: #{lines[line]}" : '')
      exit code
    end
  end
end
