require 'faraday'
require 'faraday_middleware'
require 'sinatra'
require 'date'

# monkeypatch date 
# to handle nil and empty strings gracefully
class DateTime
  def self.safe_parse(value, default = nil)
    DateTime.parse(value.to_s)
  rescue ArgumentError
    default
  end
end

DATE_FORMAT = "%a %b %-d"   # ignore time, all complaintes arrive at 12:00:00 am (?)
DATETIME_FORMAT = "%a %b %-d at %I:%M%p"   # ignore time, all complaintes arrive at 12:00:00 am (?)

get '/' do
  "<style>p {background-color: #F1F1F2; float:left; width: 150px; text-align: center; padding: 5px; margin: 5px;} p img { width: 120px; }</style>" +
  "<h1>All the feeds</h1> <ul>" + 
  "<p><a href='/nyc-311-rodent'><img src='rat.png'><br>NYC 311 Rodent Complaints</a></li></p>" + 
  "<p><a href='/nyc-311-water'><img src='water.png'><br>NYC 311 Water System Complaints</a></p>" + 
  "</ul> "

end

get '/nyc-311-rodent' do
  url = URI('https://data.cityofnewyork.us/resource/erm2-nwe9.json')
  url.query = Faraday::Utils.build_query(
    '$order' => 'created_date DESC',
    '$limit' => 100,
    '$where' => "complaint_type = 'Rodent'"+
    " AND unique_key IS NOT NULL"+
    " AND latitude IS NOT NULL"+
    " AND longitude IS NOT NULL"+
    " AND created_date > '#{(DateTime.now - 7).iso8601}'"
  )

  connection = Faraday.new(:url => url.to_s) do |faraday|
    faraday.request  :url_encoded   
    faraday.response :json
    faraday.adapter  Faraday.default_adapter
  end
  response = connection.get
  collection = response.body
  features = collection.map do |record|
    a = record['incident_address'] || ""
    created_date                   = DateTime.safe_parse(record['created_date'])
    created_date_formatted         = created_date.strftime(DATE_FORMAT)
    request.logger.info("turned #{record['created_date']} into #{created_date_formatted}")
    due_date                       = DateTime.safe_parse(record['due_date'])
    closed_date                    = DateTime.safe_parse(record['closed_date'])
    resolution_action_updated_date = DateTime.safe_parse(record['resolution_action_updated_date'])
    if record['status'] == 'Closed' then
      title = "Closed #{record['descriptor']} at #{a.downcase} (#{record['location_type']}) originally recorded at #{created_date.strftime(DATE_FORMAT)} was closed at #{closed_date.strftime(DATE_FORMAT)}."
    else
      title = "#{record['descriptor']} at #{a.downcase} called in on #{created_date.strftime(DATE_FORMAT)}."
    end
    {
      'id' => record['unique_key'],
      'type' => 'Feature',
      'properties' => record.merge('title' => title),
      'geometry' => {
      'type' => 'Point',
      'coordinates' => [
        record['longitude'].to_f,
        record['latitude'].to_f
    ]
    }
    }
  end

  content_type :json
  JSON.pretty_generate('type' => 'FeatureCollection', 'features' => features)
end

get '/nyc-311-water' do
  url = URI('https://data.cityofnewyork.us/resource/erm2-nwe9.json')
  url.query = Faraday::Utils.build_query(
    '$order' => 'created_date DESC',
    '$limit' => 100,
    '$where' => "complaint_type = 'Water System'"+
    " AND unique_key IS NOT NULL"+
    " AND latitude IS NOT NULL"+
    " AND longitude IS NOT NULL"+
    " AND created_date > '#{(DateTime.now - 7).iso8601}'"
  )

  connection = Faraday.new(:url => url.to_s) do |faraday|
    faraday.request  :url_encoded   
    faraday.response :json
    faraday.adapter  Faraday.default_adapter
  end
  response = connection.get
  collection = response.body
  features = collection.map do |record|
    a = record['incident_address'] || ""
    created_date                   = DateTime.safe_parse(record['created_date'])
    created_date_formatted         = created_date.strftime(DATETIME_FORMAT)
    request.logger.info("turned #{record['created_date']} into #{created_date_formatted}")
    due_date                       = DateTime.safe_parse(record['due_date'])
    closed_date                    = DateTime.safe_parse(record['closed_date'])
    resolution_action_updated_date = DateTime.safe_parse(record['resolution_action_updated_date'])
    if record['status'] == 'Closed' then
      title = "Closed #{record['descriptor']} at #{a.downcase} (#{record['location_type']}) originally recorded at #{created_date.strftime(DATETIME_FORMAT)} was closed at #{closed_date.strftime(DATE_FORMAT)}."
    else
      title = "#{record['descriptor']} at #{a.downcase} called in on #{created_date.strftime(DATETIME_FORMAT)}."
    end
    {
      'id' => record['unique_key'],
      'type' => 'Feature',
      'properties' => record.merge('title' => title),
      'geometry' => {
      'type' => 'Point',
      'coordinates' => [
        record['longitude'].to_f,
        record['latitude'].to_f
    ]
    }
    }
  end

  content_type :json
  JSON.pretty_generate('type' => 'FeatureCollection', 'features' => features)
end
