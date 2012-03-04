require 'sinatra'
require 'net/http'
require 'uri'
require 'json'

require './templates'

# Main index page.
get '/' do
    template :index, "Welcome!"
end

# A name was submitted to us for processing. But is it a species name
# or a higher taxon?
get '/submit' do
    # Were we given any 'nomen'?
    if (not params.key?('nomen')) or (params[:nomen] == '') then
        redirect to('/')
    end
    
    redirect to('/taxon/' + escape(params[:nomen]))
end

# For species-level taxa.
get '/species/*' do |species|
    species = escape_html(species)

    template :species, "species " + species, {
        'type' =>    'species',
        'nomen' =>   species
    }
end

# For non-species taxa.
get '/taxon/*' do |taxon|
    # How many names do we have?
    names = taxon.split(/\s+/)

    # Binomials have two or three names.
    if names.count >= 2 and names.count <= 3 then
        # TODO - for now, just treat everything as a taxon
        # redirect to('/species/' + escape(taxon))
    end

    # One word names are higher taxa.
    if names.count == 1 then
        # Taxon names are always first letter capital, so let's
        # do that.
        taxon.downcase!
        taxon.capitalize!
    end

    (wikispecies_title, wikispecies_status) = get_wikispecies_info(taxon)
    (namebank_id, namebank_status) = get_ubio_namebank_info(taxon)
    (eol_id, eol_status) = get_eol_info(taxon)

    # Finally, we need to escape it before presenting it back to the user.
    taxon = escape_html(taxon)
    template :taxon, "taxon " + taxon, {
        'type' =>    'taxon',
        'nomen' =>   taxon,

        'wikispecies_title' =>  wikispecies_title,
        'wikispecies_status' => wikispecies_status,

        'namebank_id' =>        namebank_id,
        'namebank_status' =>    namebank_status,

        'eol_id' =>             eol_id,
        'eol_url' =>            eol_url(eol_id),
        'eol_status' =>         eol_status
    }
end

def get_wikispecies_info(taxon)
    url = 'http://species.wikimedia.org/wiki/%s' % taxon

    return [nil, "Could not check for Wikispecies page at #{url}"]
end

def get_ubio_namebank_info(taxon)
    return [nil, 'Could not obtain uBio API key']
end

def eol_url(id)
    if id.to_i() == 0 then return nil end

    return sprintf("http://eol.org/pages/%d/overview", id)
end

def get_eol_info(taxon)
    url = 'http://eol.org/api/search/1.0/%s.json?exact=1'
    url = sprintf(url, escape(taxon).gsub('+', '%20'))

    uri = URI.parse(url)
    res = Net::HTTP.start(uri.host, uri.port) {|http|
        http.get(url)
    }

    results = JSON.parse(res.body)
    if results.key?('results') and results['totalResults'] > 0 then
        return [results['results'][0]['id'], "#{results['totalResults']} results found, using the first one."]
    else
        return [nil, "Taxon '" + escape(taxon) + "' could not be found in EOL"]
    end
end
