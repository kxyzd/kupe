require 'sinatra'
require 'forwardable'

enable :sessions

Host = 'localhost:4567'

class Room
  def initialize(id, key, size)
    @id, @key, @size = id, key, size
    @link = "/room/#{@id}"
    @questions = []
  end

  def ask(question)
    if @questions.size < @size
      @questions << question
    else
      raise 'the room is closed'
    end
  end

  def answere(index)
    question = @questions[index]
    @questions[index] = [:answered, question]
  end

  def closed?
    @questions.size == @size
  end

  attr_reader :id, :key, :link, :questions
end

class RoomFactory
  def initialize
    @id = 115 # magic!
    # @used_keys = {}
  end

  def create(*a, **kw)
    Room.new(new_id, generate_key, *a, **kw)
  end

  private

  def new_id
    @id += 1
  end

  def generate_key
    # ToDo: Изменить алгоритм и добавить проверку на
    # уникальность ключа.
    @id.digits.map { (_1 + rand('a'.ord..'z'.ord)).chr }.join
  end
end

class Rooms
  def initialize(check_every: 5)
    @rooms_hash = {} # для получения комнат по id
    @factory = RoomFactory.new
    # Через сколько созданий комнат сделать проверку и
    # удалить закрытые(убрать ссылки на них), чтобы GC
    # смог бы их убрать.
    @check_every = check_every
    @created_room = 0
  end

  def create_room(*a, **kw)
    delete_closed_rooms
    room = @factory.create(*a, **kw)
    @rooms_hash[room.id] = room
    room
  end

  def [](id)
    raise TypeError unless id.kind_of? Integer
    @rooms_hash[id]
  end

  private

  def delete_closed_rooms
    if (@created_room += 1) == @chech_every
      @rooms_hash.each do |id, room|
        @rooms_hash[id] = nil if room.closed?
      end
    end
  end
end

$rooms = Rooms.new

get '/' do
  erb :index
end

get '/room/:id' do
  # ToDo: Сделать нормальный "хендлинг" некорректного ...
  return 'error' unless params['id']&.match? /\A\d+\z/

  id = params['id'].to_i
  room = $rooms[id]

  if room and session['key'] == room.key
    erb :master_room, locals: {
      room: room,
      link: "#{Host}#{room.link}"
    }
  elsif room and params['asked'] != room.id and not room.closed?
    erb :user_room, locals: { room: room }
  elsif room&.closed?
    'Комната закрыта'
  elsif params['asked']
    'Вопрос уже был задан'
  else
    # ToDo: сделать уведомление, что такой комнаты нет!
    'Такой комнаты нет!'
  end
end

post '/create' do
  if size = params['size'] and size =~ /\A\d+\z/
    size = size.to_i
    room = $rooms.create_room size
    session['key'] = room.key
    redirect room.link
  else
    # ToDo: оброботка плохого исхода(((
    'Ошибка в запросе на <b>/create</b>'
  end
end

post '/create_question' do
  # ToDo: Сделать нормальный "хендлинг" некорректного ...
  return 'error' unless params['id']&.match? /\A\d+\z/

  # Сделать невозможным задавать несколько вопросов
  return 'error asked' if session['asked']&.== params['id'].to_i

  # Чтобы узнать, что правильно составлен запрос.
  # ToDo: make красиво!
  until session['question'].nil?
    pp session
    return 'error que'
  end

  id = params['id'].to_i
  room = $rooms[id]
  session['asked'] = id

  begin
    # ToDo: Сделать валидацию
    p room.ask normalize params['question']

    'ok3'
  rescue
    # ToDo: Сделать!
    # Больше задать вопрос нельзя!!!
    'bad'
  end
end

helpers do
  def normalize(string)
    # ToDo: Что-то ещё сделать - хз. Тупые
    # школьники-хацкеры мучают бедный вебдев.
    string.gsub(?<, '&lt;').gsub(?>, '&gt;')
  end
end
