require 'radius'
require 'pp'

def template(filename, pagetitle, vars = {})
    context = Radius::Context.new { |c|
        c.define_tag 'version' do
            "0.1"
        end

        c.define_tag 'pagetitle' do
            pagetitle
        end

        c.define_tag 'print' do |tag|
            if vars.key?(tag.attr['name']) then
                vars[tag.attr['name']]
            else
                '???'
            end
        end

        c.define_tag 'if_def' do |tag|
            if vars.key?(tag.attr['name']) then
                tag.expand()
            else
                ''
            end
        end

        c.define_tag 'print_if' do |tag|
            if vars.key?(tag.attr['name']) then
                vars[tag.attr['name']]
            else
                ''
            end
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
