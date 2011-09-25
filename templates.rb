require 'radius'

def template(filename, pagetitle)
    context = Radius::Context.new { |c|
        c.define_tag 'version' do
            "0.1"
        end

        c.define_tag 'pagetitle' do
            pagetitle
        end
    }

    parser = Radius::Parser.new(context, :tag_prefix => 'r')

    header =    IO.read("templates/header.rad")
    body =      IO.read("templates/" + filename.to_s + ".rad")
    footer =    IO.read("templates/footer.rad")
        
    # Final return value.
    parser.parse(header) +
    parser.parse(body) +
    parser.parse(footer)
end
