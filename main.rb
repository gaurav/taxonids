require 'sinatra'
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
    
    # How many names do we have?
    names = params[:nomen].split(/\s+/)

    print "Names: " + names.join(', ')

    # Binomials have two or three names.
    if names.count >= 2 and names.count <= 3 then
        redirect to('/species/' + escape(params[:nomen]))
    end

    # One word names are higher taxa.
    if names.count == 1 then
        redirect to('/taxon/' + escape(params[:nomen]))
    end

    # Anything else is ... a bit of a mystery. But let's pretend
    # that they are taxa.
    redirect to('/taxon/' + escape(params[:nomen]))
end

# For species-level taxa.
get '/species/*' do |species|
    species = escape_html(species)

    template :species, "Species " + species, {
        'type' =>    'species',
        'nomen' =>   species
    }
end

# For non-species taxa.
get '/taxon/*' do |taxon|
    taxon = escape_html(taxon)

    template :taxon, "Taxon " + taxon, {
        'type' =>    'taxon',
        'nomen' =>   taxon
    }
end
