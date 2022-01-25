require 'net/http'
require 'nokogiri'

class BowlScraper
  def initialize(url)
    @site = load_site(url)
  end

  def bowls
    load_bowls
  end

  private

  def determine_point_value(bowl_name)
    bowl_name.downcase.include?("semifinal") ? 2 : 1
  end

  def parse_bowl(date, bowl)
    name = bowl.css('strong').text.strip
    data = bowl.children.last
    teams = data.children.first.text.split(' vs. ')
    airing = data.children[2].text.split(' | ')
    location = data.children.last.text.split(' in ')
    {
      ncaa_id: data.attributes['href'].text.split('/').last.to_i,
      points: determine_point_value(name),
      name: name,
      away: teams[0].strip.sub(/^\w*. \d* /, ''),
      home: teams[1].strip.sub(/^\w*. \d* /, ''),
      start: (DateTime.parse (date.to_s + " " + airing[0].strip + "EST")),
      tv: airing[1].strip,
      stadium: location[0].strip,
      location: location[1].strip
    }
  rescue
    nil
  end

  def parse_championship
    {
      ncaa_id: nil,
      points: 4,
      name: 'College Football Playoff National Championship Game',
      away: nil,
      home: nil,
      start: nil,
      tv: nil,
      stadium: nil,
      location: nil
    }
  end

  def parse_date(date)
    Date.strptime(date.text, "%A, %b. %e") unless date.nil?
  rescue
    nil
  end

  def load_bowls
    bowls = @site.css('.article-body').css('p').map do |p|
      next_date = parse_date(p.previous_element)
      date = next_date.nil? ? Date.new : next_date
      parse_bowl(date, p)
    end
    bowls << parse_championship
    bowls.compact
  end
  
  def load_site(url)
    Nokogiri::HTML(Net::HTTP.get(URI(url)))
  end
end
