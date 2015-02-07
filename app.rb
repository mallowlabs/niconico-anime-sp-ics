# coding: utf-8
require 'sinatra'
require 'nokogiri'
require 'open-uri'
require 'icalendar'
require 'tmp_cache'
require 'digest/md5'

include Icalendar

class NamedCalendar < Calendar
  ical_property 'x_wr_calname'
end

get '/' do
  '<h1>It works!</h1>'
end

get '/ics' do
  # fetch
  source = fetch('http://ch.nicovideo.jp/anime-sp')

  # parse
  html = Nokogiri::HTML(source, nil)
  animes = html.css('.g-live-list li div.p-live-body').map do |div|
    anime = Event.new
    anime.summary = div.css('.g-live-title a').text.strip
    anime.url = div.css('.g-live-title a').first.attributes['href'].text.strip

    month_date = div.css('.g-live-airtime strong').text.strip
    month = month_date.split('/')[0].to_i
    date = month_date.split('/')[1].to_i
    time = div.css('.g-live-airtime').children.last.text.gsub('-', '').strip
    hour = time.split(':')[0].to_i
    minute = time.split(':')[1].to_i

    start_in_this_year = DateTime.civil(Time.now.year, month, date, (hour % 24), minute)
    start_in_this_year = start_in_this_year.next_day if hour >= 24
    anime.start = [start_in_this_year, start_in_this_year.next_year].min_by {|d| (d - DateTime.now).abs}
    anime
  end

  # render
  host = request.host
  cal = NamedCalendar.new
  cal.x_wr_calname = 'ニコニコアニメスペシャル'
  animes.each do |anime|
    cal.event do
      dtstart anime.start, {'TZID' => ['Asia/Tokyo']}
      summary normalize_title(anime.summary)
      url anime.url
      uid "#{Digest::MD5.hexdigest(anime.url)}@#{host}"
    end
  end
  cal.to_ical
end

private
def fetch(url, expire = 3600)
  TmpCache.get(url) || TmpCache.set(url, open(url).read, expire)
end

def normalize_title(title)
  title.gsub(/ニコニコアニメスペシャル/, '').gsub(/^【.+】/,'')
end
