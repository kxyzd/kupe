require_relative 'guu/guu'

code = %(
sub main
  set z 333
  set xyz z
  print xyz
  call foo
  print 111
sub foo
  print z
)

Guu::PhasesBuilder.new do
  bind 'Синтаксический анализ: Токинизация' do |source|
    Guu::Frontend.tokenize source
  end

  bind 'Синтаксический анализ: Парсинг' do |(lines, tokens)|
    Guu::Frontend.parse(tokens, lines: lines)
  end

  bind 'Исполнение программы' do |_symbol_table, program|
    Guu::Interpreter.new(program).exec
  end
end.run(code).then(&method(:p))
