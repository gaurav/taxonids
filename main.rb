require 'rubygems'

require 'sinatra'
require 'net/http'
require 'uri'
require 'json'
require 'xmlsimple'

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

    # This is fine for now, but it does result in a BUG:
    # it is now impossible to incorporate '+' into a taxon
    # name. 
    taxon.gsub!('+', ' ')
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

    existing_ids = get_existing_ids(taxon)
    (wikispecies_title, wikispecies_status) = get_wikispecies_info(taxon)
    (ncbi_id, ncbi_status) = get_ncbi_taxonomy_info(taxon)
    (commons_title, commons_status) = get_commons_info(taxon)
    (namebank_id, namebank_status) = get_ubio_namebank_info(taxon)
    (eol_id, eol_status) = get_eol_info(taxon)

    # Finally, we need to escape it before presenting it back to the user.
    taxon = escape_html(taxon)
    template :taxon, "taxon " + taxon, {
        'type' =>    'taxon',
        'nomen' =>   taxon,

        'wikipedia_url' => "http://en.wikipedia.org/wiki/" + URI.escape(taxon),
        
        'message' => existing_ids['unknown'],

        'wikispecies_title' =>  wikispecies_title,
        'wikispecies_status' => wikispecies_status,
        'wikispecies_title_existing' => existing_ids['wikispecies_title'],
        'wikispecies_title_final' => existing_ids['wikispecies_title'] || wikispecies_title,

        'commons_title' =>      commons_title,
        'commons_status' =>     commons_status,
        'commons_title_existing' => existing_ids['commons_title'],
        'commons_title_final' =>    existing_ids['commons_title'] || commons_title,

        'ncbi_id' =>            ncbi_id,
        'ncbi_status' =>        ncbi_status,
        'ncbi_id_existing' =>   existing_ids['ncbi_id'],
        'ncbi_id_final' =>      existing_ids['ncbi_id'] || ncbi_id,

        'namebank_id' =>        namebank_id,
        'namebank_status' =>    namebank_status,

        'eol_id' =>             eol_id,
        'eol_url' =>            eol_url(eol_id),
        'eol_status' =>         eol_status,
        'eol_id_existing' =>    existing_ids['eol_id'],
        'eol_url_existing' =>   eol_url(existing_ids['eol_id']),
        'eol_id_final' =>       existing_ids['eol_id'] || eol_id
    }
end

def get_existing_ids(taxon)
    url = "http://en.wikipedia.org/w/api.php?action=query&titles=" + URI.escape(taxon) + "&prop=extlinks&format=xml&ellimit=500"
    res = http_get(url)
    data = XmlSimple.xml_in(res.body)

    existing_ids = {}
    existing_ids['unknown'] = ""

    node = data['query'][0]['pages'][0]['page'][0]['extlinks']
    if node == nil then
        return existing_ids
    end
    extlinks = node[0]['el']

    extlinks.each {|x|
        url = x['content']
        if url.match(/species\.wikimedia\.org\/wiki\/(\w+)/) then
            str = $1
            str.gsub!('_', ' ')
            existing_ids['wikispecies_title'] = str
        elsif url.match(/commons\.wikimedia\.org\/wiki\/([\w:]+)/) then
            str = $1
            str.gsub!('_', ' ')
            existing_ids['commons_title'] = str
        elsif url.match(/en\.wikiquote\.org\/wiki\/(\w+)/) then
            str = $1
            str.gsub!('_', ' ')
            existing_ids['wikiquote_title'] = str
        elsif url.match(/eol\.org\/pages\/(\d+)/) then
            existing_ids['eol_id'] = $1
        elsif url.match(/www\.ncbi\.nlm\.nih\.gov\/Taxonomy\/Browser\/wwwtax\.cgi\?mode=Info&id=(\d+)/) then
            existing_ids['ncbi_id'] = $1
        elsif url.match(/itis\.gov\/servlet\/SingleRpt\/SingleRpt\?search_topic=TSN&search_value=(\d+)/) then
            existing_ids['itis_id'] = $1
        else
            existing_ids['unknown'] += url + ", "
        end
    }

    return existing_ids
end

def get_wikispecies_info(taxon)
    url = 'http://species.wikimedia.org/wiki/%s' % URI.escape(taxon)
    res = http_head(url)

    if res.code == '404' then
        return [nil, "No page found <a href='#{url}'>on Wikispecies</a>"]
    else
        return [taxon, "Page found for taxon '%s'" % taxon]
    end
end

def get_commons_info(taxon)
    url = 'http://commons.wikimedia.org/wiki/Category:%s' % URI.escape(taxon)
    res = http_head(url)

    if res.code == '404' then
        return [nil, "No page found <a href='#{url}'>on the Wikimedia Commons</a>"]
    else
        return ["Category:" + taxon, "Page found for taxon '%s'" % taxon]
    end
end

def get_ncbi_taxonomy_info(taxon)
    url = "http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?mode=Undef&name=#{URI.escape(taxon)}&lvl=0&srchmode=1"
    res = http_get(url)

    if res.body.match(/<em>Taxonomy ID: <\/em>(\d+)<br>/i) then
        return [$1, "Taxonomy ID found <a href='#{url}'>on NCBI Taxonomy</a>"]
    else
        return [nil, "No taxonomy id found <a href='#{url}'>on NCBI Taxonomy</a>"]
    end
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
    url = sprintf(url, URI.escape(taxon))

    res = http_get(url)
    results = JSON.parse(res.body)
    if results.key?('results') and results['totalResults'] > 0 then
        return [results['results'][0]['id'], "#{results['totalResults']} results found, using the first one."]
    else
        return [nil, "Taxon '" + escape(taxon) + "' could not be found in EOL"]
    end
end

def http_get(url)
    uri = URI.parse(url)
    res = Net::HTTP.start(uri.host, uri.port) {|http|
        http.get(url, {"User-Agent" => "taxonids/1.0 http://github.com/gaurav/taxonids"})
    }

    if res.is_a?(Net::HTTPRedirection) then
        res = http_get(res['location'])
    end

    return res
end

def http_head(url)
    uri = URI.parse(url)
    res = Net::HTTP.start(uri.host, uri.port) {|http|
        http.head(url, {"User-Agent" => "taxonids/1.0 http://github.com/gaurav/taxonids"})
    }

    if res.is_a?(Net::HTTPRedirection) then
        res = http_head(res['location'])
    end

    return res
end
