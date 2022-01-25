require 'net/http'
require 'nokogiri'

class GamePod
  attr_reader :date, :games

  def initialize(gamepod_text)
    @date = parse_date(gamepod_text)
    @games = process_games(gamepod_text)
  end

  private

  def parse_date(gamepod_text)
    Date.parse gamepod_text.css('h6').text
  end

  def process_games(gamepod_text)
    gamepod_text.css('.gamePod-type-game').css('a').map do |game|
      Game.new(game)
    end
  end
end

class Game
  attr_reader :game_id, :status, :time, :scores, :winner

  def initialize(game_text)
    @ncaa_id = parse_game_id(game_text)
    @status = parse_status(game_text)
    @time = parse_time(game_text)
    @scores = parse_scores(game_text)
    @winner = parse_winner(game_text)
  end

  private

  def parse_game_id(game_text)
    game_text.attributes['href'].text.gsub('/game/', '').to_i
  end

  def parse_status(game_text)
    game_text.css('.gamePod-status').text.downcase
  end

  def parse_scores(game_text)
    game_text.css('.gamePod-game-teams').css('li').map do |team|
      {
        name: team.css('.gamePod-game-team-name').text,
        score: team.css('.gamePod-game-team-score').text.to_i
      }
    end
  end

  def parse_time(game_text)
    return nil unless @status == 'live'

    time = game_text.css('.gamePod-description').text.strip
    if time == 'HALF' then 'HALF'
    else
      {
        remaining: time.split.first,
        quarter: time.split.last
      }
    end
  end

  def parse_winner(game_text)
    winner = game_text.css('.gamePod-game-teams').css('li').css('.winner')
    winner.css('.gamePod-game-team-name').text
  end
end

class ScoreboardScraper
  attr_reader :season

  def initialize(season = nil)
    @season = season || DateTime.now.year
  end

  def game(game_id)
    games.select do |game|
      game.game_id == game_id
    end
    games.first
  end

  def games
    get_games_by_status(nil)&.map do |game_text|
      Game.new(game_text)
    end
  end

  def games_by_date(date)
    gamepod_text = get_gamepod(date)
    GamePod.new(gamepod_text).games
  end

  def games_by_status(game_status)
    get_games_by_status(game_status)&.map do |game_text|
      Game.new(game_text)
    end
  end

  private

  def site
    uri = URI("https://www.ncaa.com/scoreboard/football/fbs/#{@season}/P")
    Nokogiri::HTML(Net::HTTP.get(uri))
  end

  def get_gamepod(date)
    pods = site.css('.gamePod_content-division')&.reject do |pod|
      date != (Date.parse pod.css('h6').text)
    end
    pods.first
  end

  def get_games_by_status(status = nil)
    games = site.css('.gamePod-type-game')
    case status
    when 'final'
      games&.css('.status-final')&.css('a')
    when 'live'
      games&.css('.status-live')&.css('a')
    when 'pre'
      games&.css('.status-pre')&.css('a')
    else
      games&.css('a')
    end
  end
end
