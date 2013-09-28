require 'sinatra'
require 'nokogiri'
require 'open-uri'
require 'icalendar'
require 'tmp_cache'

include Icalendar

get '/' do
  '<h1>It works!</h1>'
end

get '/ics' do
  # fetch
  source = fetch('http://ch.nicovideo.jp/anime-sp')

  # parse
  html = Nokogiri::HTML(source, nil)
  animes = html.css('.g-live-list li div.p-live2').map do |div|
    anime = Event.new
    anime.summary = div.css('.g-live-title a').text.strip
    anime.description = div.css('.g-live-title a').first.attributes['href'].text.strip

    year = Time.now.year
    month_date = div.css('.g-live-airtime strong').text.strip
    month = month_date.split('/')[0].to_i
    date = month_date.split('/')[1].to_i
    time = div.css('.g-live-airtime').children.last.text.gsub('-', '').strip
    hour = time.split(':')[0].to_i
    minute = time.split(':')[1].to_i

    anime.start = DateTime.civil(year, month, date, hour, minute)
    anime
  end

  # render
  cal = Calendar.new
  cal.timezone { timezone_id 'Tokyo/Japan' }
  animes.each { |anime| cal.add_event(anime) }
  cal.to_ical
end

private
def fetch(url, expire = 3600)
  TmpCache.get(url) || TmpCache.set(url, open(url).read, expire)
end
