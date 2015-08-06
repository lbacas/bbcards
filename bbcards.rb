#!/usr/bin/env ruby

# #######################################################################
#
# bbcards is loosely based on an earlier, but more simplistic project
# called cahgen that also uses ruby/prawn to generate CAH cards,
# which can be found here: https://github.com/jyruzicka/cahgen
#
# bbcards is free software: you can redistribute it
# and/or modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, either version 2 of
# the License, or (at your option) any later version.
#
# bbcards is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Hadoop-Gpl-Compression. If not, see
# <http://www.gnu.org/licenses/>
#
#
# #######################################################################


require "prawn"
require "prawn/measurement_extensions"
require "rbconfig"
include RbConfig

# Disable warning: PDF's built-in fonts have very limited support for internationalized text. If you need full UTF-8 support, consider using a TTF font instead.
Prawn::Font::AFM.hide_m17n_warning = true


MM_PER_INCH=25.4

MARGIN_HEIGHT = 15.mm;
MARGIN_WIDTH  = 10.mm;


def get_card_geometry(card_width_inches=2.0, card_height_inches=2.0, card_font_size=14, paper_format="LETTER", rounded_corners=false, one_card_per_page=false)
	card_geometry = Hash.new
	card_geometry["card_width"]        = (MM_PER_INCH*card_width_inches).mm
	card_geometry["card_height"]       = (MM_PER_INCH*card_height_inches).mm

	card_geometry["rounded_corners"]   = rounded_corners == true ? ((1.0/8.0)*MM_PER_INCH).mm : (rounded_corners == false ? 0 : rounded_corners)
	card_geometry["one_card_per_page"] = one_card_per_page

	if card_geometry["one_card_per_page"]
		card_geometry["paper_width"]       = card_geometry["card_width"]
		card_geometry["paper_height"]      = card_geometry["card_height"]
	else
		card_geometry = get_paper_size(paper_format, card_geometry)
	end


	card_geometry["cards_across"] = ( (card_geometry["paper_width"] - MARGIN_WIDTH) / card_geometry["card_width"]).floor
	card_geometry["cards_high"]   = ( (card_geometry["paper_height"] - MARGIN_HEIGHT) / card_geometry["card_height"]).floor

	card_geometry["page_width"]   = card_geometry["card_width"] * card_geometry["cards_across"]
	card_geometry["page_height"]  = card_geometry["card_height"] * card_geometry["cards_high"]

	card_geometry["margin_left"]  = (card_geometry["paper_width"] - card_geometry["page_width"] ) / 2
	card_geometry["margin_top"]   = (card_geometry["paper_height"] - card_geometry["page_height"] ) / 2

	card_geometry["font_size"] = card_font_size

	return card_geometry;
end

def get_card_texts(lang="en")
	card_texts = Hash.new

	case lang
	  when "es", "ES", "es-ES"
		card_texts["draw"] = "COGE"
	  	card_texts["pick"] = "ELIGE"
	  when "en", "EN", "en-UK", "en-US"
		card_texts["draw"] = "DRAW"
		card_texts["pick"] = "PICK"
	  else
		card_texts["draw"] = "DRAW"
  		card_texts["pick"] = "PICK"
	end

	return card_texts;
end

def get_paper_size(format, card_geometry)
	case format
	  when "DINA4"
		card_geometry["paper_height"]  = 297.mm;
  		card_geometry["paper_width"]   = 210.mm;
	  when "DINA4_"
  		card_geometry["paper_height"]  = 210.mm;
    	card_geometry["paper_width"]   = 297.mm;
	  when "LETTER"
		card_geometry["paper_height"]  = (MM_PER_INCH*11.0).mm;
  		card_geometry["paper_width"]   = (MM_PER_INCH*8.5).mm;
	  when "LETTER_"
  		card_geometry["paper_height"]  = (MM_PER_INCH*8.5).mm;
    	card_geometry["paper_width"]   = (MM_PER_INCH*11.0).mm;
	  else
		# LETTER
		card_geometry["paper_height"]  = (MM_PER_INCH*11.0).mm;
		card_geometry["paper_width"]   = (MM_PER_INCH*8.5).mm;
	end

	return card_geometry
end

def draw_grid(pdf, card_geometry)
	#Generate cards
	pdf.stroke do
			0.upto(card_geometry["cards_across"]-1) do |i|
				0.upto(card_geometry["cards_high"]-1) do |j|
					#rectangle bounded by upper left corner, horizontal measured from the left, vertical measured from the bottom
					pdf.rounded_rectangle(
						[i*card_geometry["card_width"], card_geometry["card_height"]+(j*card_geometry["card_height"])],
						card_geometry["card_width"],
						card_geometry["card_height"],
						card_geometry["rounded_corners"]
					)
				end
			end
		end

	pdf.dash(3, :space => 2)
	pdf.stroke do
		#Draw vertical cut helpers
		0.upto(card_geometry["cards_across"]) do |i|
			pdf.line(
				[card_geometry["card_width"]*i, -100],
				[card_geometry["card_width"]*i, -8]
			)
			pdf.line(
				[card_geometry["card_width"]*i, card_geometry["page_height"] + 8],
				[card_geometry["card_width"]*i, card_geometry["page_height"] + 100]
			)
		end

		#Draw horizontal cut helpers
		0.upto(card_geometry["cards_high"]) do |i|
			pdf.line(
				[-100,                        card_geometry["card_height"]*i],
				[-8,                          card_geometry["card_height"]*i]
			)
			pdf.line(
				[card_geometry["page_width"] + 8,   card_geometry["card_height"]*i],
				[card_geometry["page_width"] + 100, card_geometry["card_height"]*i]
			)

		end
	end
	pdf.undash
end

def box(pdf, card_geometry, index, &blck)
	# Determine row + column number
	column = index%card_geometry["cards_across"]
	row = card_geometry["cards_high"] - index/card_geometry["cards_across"]

	# Margin: 10pt
	x = card_geometry["card_width"] * column + 10
	y = card_geometry["card_height"] * row - 10

	pdf.bounding_box([x,y], width: card_geometry["card_width"]-20, height: card_geometry["card_height"]-10, &blck)
end

def draw_logos(pdf, card_geometry, icon, deck_name)
	idx=0
	while idx < card_geometry["cards_across"] * card_geometry["cards_high"]
		box(pdf, card_geometry, idx) do
			logo_max_height = 15
			logo_max_width = card_geometry["card_width"]/2
			pdf.image icon, fit: [logo_max_width, logo_max_height], at: [pdf.bounds.left, pdf.bounds.bottom+25]
			pdf.text_box deck_name, size: 6, align: :left, width: 200, at: [pdf.bounds.left+22, pdf.bounds.bottom+18]
		end
		idx = idx + 1
	end
end


def render_card_page(pdf, card_geometry, card_texts, icon, deck_name, statements, directory, is_black, page_number)
	pdf.font "Helvetica", :style => :normal
	pdf.font_size = card_geometry["font_size"]
	pdf.line_width(0.5);

	if(is_black)
		pdf.canvas do
			pdf.rectangle(pdf.bounds.top_left, pdf.bounds.width, pdf.bounds.height)
		end

		pdf.fill_and_stroke(:fill_color=>"000000", :stroke_color=>"000000") do
			pdf.canvas do
				pdf.rectangle(pdf.bounds.top_left,pdf.bounds.width, pdf.bounds.height)
			end
		end
		pdf.stroke_color "ffffff"
		pdf.fill_color "ffffff"
	else
		pdf.stroke_color "000000"
		pdf.fill_color "000000"
	end

	cards_per_page = card_geometry["cards_high"] * card_geometry["cards_across"]
	card_number = page_number * cards_per_page

	draw_grid(pdf, card_geometry)
	statements.each_with_index do |line, idx|
		box(pdf, card_geometry, idx) do

			line_parts = line.split(/\t/)
			card_text = line_parts.shift
			card_text = card_text.gsub(/\\n */, "\n")
			card_text = card_text.gsub(/\\t/,   "\t")

			card_text = card_text.gsub("<b>", "[[[b]]]")
			card_text = card_text.gsub("<i>", "[[[i]]]")
			card_text = card_text.gsub("<u>", "[[[u]]]")
			card_text = card_text.gsub("<strikethrough>", "[[[strikethrough]]]")
			card_text = card_text.gsub("<sub>", "[[[sub]]]")
			card_text = card_text.gsub("<sup>", "[[[sup]]]")
			card_text = card_text.gsub("<font", "[[[font")
			card_text = card_text.gsub("<color", "[[[color")
			card_text = card_text.gsub("<br>", "[[[br/]]]")
			card_text = card_text.gsub("<br/>", "[[[br/]]]")
			card_text = card_text.gsub("<br />", "[[[br/]]]")

			card_text = card_text.gsub("</b>", "[[[/b]]]")
			card_text = card_text.gsub("</i>", "[[[/i]]]")
			card_text = card_text.gsub("</u>", "[[[/u]]]")
			card_text = card_text.gsub("</strikethrough>", "[[[/strikethrough]]]")
			card_text = card_text.gsub("</sub>", "[[[/sub]]]")
			card_text = card_text.gsub("</sup>", "[[[/sup]]]")
			card_text = card_text.gsub("</font>", "[[[/font]]]")
			card_text = card_text.gsub("</color>", "[[[/color]]]")


			card_text = card_text.gsub(/</, "&lt;");


			card_text = card_text.gsub("\[\[\[b\]\]\]", "<b>")
			card_text = card_text.gsub("\[\[\[i\]\]\]", "<i>")
			card_text = card_text.gsub("\[\[\[u\]\]\]", "<u>")
			card_text = card_text.gsub("\[\[\[strikethrough\]\]\]", "<strikethrough>")
			card_text = card_text.gsub("\[\[\[sub\]\]\]", "<sub>")
			card_text = card_text.gsub("\[\[\[sup\]\]\]", "<sup>")
			card_text = card_text.gsub("\[\[\[font", "<font")
			card_text = card_text.gsub("\[\[\[color", "<color")
			card_text = card_text.gsub("\[\[\[br/\]\]\]", "<br/>")

			card_text = card_text.gsub("\[\[\[/b\]\]\]", "</b>")
			card_text = card_text.gsub("\[\[\[/i\]\]\]", "</i>")
			card_text = card_text.gsub("\[\[\[/u\]\]\]", "</u>")
			card_text = card_text.gsub("\[\[\[/strikethrough\]\]\]", "</strikethrough>")
			card_text = card_text.gsub("\[\[\[/sub\]\]\]", "</sub>")
			card_text = card_text.gsub("\[\[\[/sup\]\]\]", "</sup>")
			card_text = card_text.gsub("\[\[\[/font\]\]\]", "</font>")
			card_text = card_text.gsub("\[\[\[/color\]\]\]", "</color>")

			# Parse card_text to obtain pick_num and additional image
			re = /(?:\[\[(\d+)\]\])?(?:\[\[img=([^\]]+)\]\])?(.*)/m
			m = re.match(card_text)

			pick_num    = m[1]
			img_data    = m[2]
			card_text   = m[3]
			card_number = card_number + 1

			# Trim card text.
			card_text = card_text.gsub(/^[\t ]*/, "")
			card_text = card_text.gsub(/[\t ]*$/, "")

			# Identify if the card is a pick-2 or pick-3 black card
			is_pick2 = false
			is_pick3 = false
			if is_black
				if pick_num.nil? or pick_num == ""
					tmpline = "a" + card_text.to_s + "a"
					parts = tmpline.split(/__+/)
					if parts.length == 3
						is_pick2 = true
					elsif parts.length >= 4
						is_pick3 = true
					end
				elsif pick_num == "2"
					is_pick2 = true
				elsif pick_num == "3"
					is_pick3 = true
				end
			end

			picknum = "0"
			if is_pick2
				picknum = "2"
			elsif is_pick3
				picknum = "3"
			elsif is_black
				picknum = "1"
			end

			statements[idx] = [card_text, picknum]

			#by default cards should be bold
			card_text = "<b>" + card_text + "</b>"

			# Text
			pdf.font "Helvetica", :style => :normal

			# Print additional image on the card.
			if not img_data.nil?
				img_data = img_data.split(/;/)
				pdf.image directory + File::Separator + img_data[0].to_s, fit: [img_data[1].to_f, img_data[2].to_f], at: [pdf.bounds.right + img_data[3].to_f, pdf.bounds.bottom + img_data[4].to_f]
			end

			# Print card text
			if is_pick3
				text_margin_bottom = 68
			elsif is_pick2
				text_margin_bottom = 55
			else
				text_margin_bottom = 35
			end
			pdf.text_box card_text.to_s, :overflow => :shrink_to_fit, :height => card_geometry["card_height"]-text_margin_bottom, :inline_format => true

			pdf.font "Helvetica", :style => :bold

			# Print card number
			pdf.text_box "#"+card_number.to_s, size: 6, align: :right, width: 30, at: [pdf.bounds.right-25, pdf.bounds.bottom+8], rotate: 15, rotate_around: :center

			#pick 2
			if is_pick2
				pdf.text_box card_texts["pick"].to_s, size:9, align: :right, width:35, at: [pdf.bounds.right-55,pdf.bounds.bottom+35], :overflow => :shrink_to_fit
				pdf.fill_and_stroke(:fill_color=>"ffffff", :stroke_color=>"ffffff") do
					pdf.circle([pdf.bounds.right-10,pdf.bounds.bottom+32],6.0)
				end
				pdf.stroke_color '000000'
				pdf.fill_color '000000'
				pdf.text_box "2", color:"000000", size:10, width:8, align: :center, at:[pdf.bounds.right-14,pdf.bounds.bottom+36]
				pdf.stroke_color "ffffff"
				pdf.fill_color "ffffff"
			end

			#pick 3
			if is_pick3
				pdf.text_box card_texts["pick"].to_s, size:9, align: :right, width:35, at: [pdf.bounds.right-55,pdf.bounds.bottom+35], :overflow => :shrink_to_fit
				pdf.fill_and_stroke(:fill_color=>"ffffff", :stroke_color=>"ffffff") do
					pdf.circle([pdf.bounds.right-10,pdf.bounds.bottom+32],6.0)
				end
				pdf.stroke_color '000000'
				pdf.fill_color '000000'
				pdf.text_box "3", color:"ff0000", size:10, width:8, align: :center, at:[pdf.bounds.right-14,pdf.bounds.bottom+36]
				pdf.stroke_color "ffffff"
				pdf.fill_color "ffffff"


				pdf.text_box card_texts["draw"].to_s, size:9, align: :right, width:35, at: [pdf.bounds.right-55,pdf.bounds.bottom+51], :overflow => :shrink_to_fit
				pdf.fill_and_stroke(:fill_color=>"ffffff", :stroke_color=>"ffffff") do
					pdf.circle([pdf.bounds.right-10,pdf.bounds.bottom+48],6.0)
				end
				pdf.stroke_color '000000'
				pdf.fill_color '000000'
				pdf.text_box "2", color:"000000", size:10, width:8, align: :center, at:[pdf.bounds.right-14,pdf.bounds.bottom+52]
				pdf.stroke_color "ffffff"
				pdf.fill_color "ffffff"
			end
		end
	end
	draw_logos(pdf, card_geometry, icon, deck_name)
	pdf.stroke_color "000000"
	pdf.fill_color "000000"

end

def load_pages_from_lines(lines, card_geometry)
	pages = []

	non_empty_lines = []
	lines.each do |line|
		line = line.gsub(/^[\t\n\r]*/, "")
		line = line.gsub(/[\t\n\r]*$/, "")
		if line != ""
			non_empty_lines.push(line)
		end
	end
	lines = non_empty_lines


	cards_per_page = card_geometry["cards_high"] * card_geometry["cards_across"]
	num_pages = (lines.length.to_f/cards_per_page.to_f).ceil

	0.upto(num_pages - 1) do |pn|
 		pages << lines[pn*cards_per_page,cards_per_page]
    	end

	return pages

end

def load_pages_from_string(string, card_geometry)
	lines = string.split(/[\r\n]+/)
	pages = load_pages_from_lines(lines, card_geometry)
	return pages
end

def load_pages_from_file(file, card_geometry)
	pages = []
	if File.exist?(file)
		lines = IO.readlines(file)
		pages = load_pages_from_lines(lines, card_geometry);
	end
	return pages
end

def load_ttf_fonts(font_dir, font_families)

	if font_dir.nil?
		return
	elsif (not Dir.exist?(font_dir)) or (font_families.nil?)
		return
	end

	font_files = Hash.new
	ttf_files=Dir.glob(font_dir + "/*.ttf")
	ttf_files.each do |ttf|
		full_name = ttf.gsub(/^.*\//, "")
		full_name = full_name.gsub(/\.ttf$/, "")
		style = "normal"
		name = full_name
		if name.match(/[_\s]Bold[_\s]Italic$/)
			style = "bold_italic"
			name = name.gsub(/[_\s]Bold[_\s]Italic$/, "")
		elsif name.match(/[_\s]Italic$/)
			style = "italic"
			name = name.gsub(/[_\s]Italic$/, "")
		elsif name.match(/[_\s]Bold$/)
			style = "bold"
			name = name.gsub(/[_\s]Bold$/, "")
		end

		name = name.gsub(/_/, " ");

		if not (font_files.has_key? name)
			font_files[name] = Hash.new
		end
		font_files[name][style] = ttf
	end

	font_files.each_pair do |name, ttf_files|
		if (ttf_files.has_key? "normal" ) and (not font_families.has_key? "name" )
			normal = ttf_files["normal"]
			italic = (ttf_files.has_key? "italic") ?  ttf_files["italic"] : normal
			bold   = (ttf_files.has_key? "bold"  ) ?  ttf_files["bold"]   : normal
			bold_italic = normal
			if ttf_files.has_key? 'bold_italic'
				bold_italic = ttf_files["bold_italic"]
			elsif ttf_files.has_key? 'italic'
				bold_italic = italic
			elsif ttf_files.has_key? 'bold'
				bold_italic = bold
			end


			font_families.update(name => {
				:normal => normal,
				:italic => italic,
				:bold => bold,
				:bold_italic => bold_italic
			})

		end
	end
end

def render_cards(directory=".", white_file="white.txt", black_file="black.txt", icon_file="icon.png", deck_name="Cards Against Humanity", output_file="cards.pdf", input_files_are_absolute=false, output_file_name_from_directory=true, recurse=true, card_geometry=get_card_geometry, card_texts=get_card_texts, white_string="", black_string="", output_to_stdout=false, title=nil )
	original_white_file = white_file
	original_black_file = black_file
	original_icon_file = icon_file
	if not input_files_are_absolute
		white_file      = directory + File::Separator + white_file
		black_file      = directory + File::Separator + black_file
		black_icon_file = directory + File::Separator + 'black_' + icon_file
		white_icon_file = directory + File::Separator + 'white_' + icon_file
		icon_file       = directory + File::Separator + icon_file
	end

	# Get icon file
	if not File.exist? icon_file
		icon_file = "./default.png"
	end

	# Get specific icon files for black or white decks
	unless File.exist? black_icon_file
		black_icon_file = icon_file
	end
	unless File.exist? white_icon_file
		white_icon_file = icon_file
	end

	if not directory.nil?
		if File.exist?(directory) and directory != "." and output_file_name_from_directory
			output_file = directory.split(File::Separator).pop + ".pdf"
		end
	end

	if output_to_stdout and title.nil?
		title = "Bigger, Blacker Cards"
	elsif title.nil? and output_file != "cards.pdf"
		title = output_file.split(File::Separator).pop.gsub(/.pdf$/, "")
	end



	white_pages = []
	black_pages = []
	if white_file == nil and black_file == nil and white_string == "" and black_string == ""
		white_string = " "
		black_string = " "
	end
	if white_string != "" || white_file == nil
		white_pages = load_pages_from_string(white_string, card_geometry)
	else
		white_pages = load_pages_from_file(white_file, card_geometry)
	end
	if black_string != "" || black_file == nil
		black_pages = load_pages_from_string(black_string, card_geometry)
	else
		black_pages = load_pages_from_file(black_file, card_geometry)
	end



	if white_pages.length > 0 or black_pages.length > 0
		pdf = Prawn::Document.new(
			page_size: [card_geometry["paper_width"], card_geometry["paper_height"]],
			left_margin: card_geometry["margin_left"],
			right_margin: card_geometry["margin_left"],
			top_margin: card_geometry["margin_top"],
			bottom_margin: card_geometry["margin_top"],
			info: { :Title => title, :CreationDate => Time.now, :Producer => "Bigger, Blacker Cards", :Creator=>"Bigger, Blacker Cards" }
		)


		case CONFIG['host_os']
		  when /mswin|windows/i
		    # Windows
		  when /linux|arch/i
		    # Linux
			load_ttf_fonts("/usr/share/fonts/truetype/msttcorefonts", pdf.font_families)
		  when /sunos|solaris/i
		    # Solaris
		  when /darwin/i
		    load_ttf_fonts("/Library/Fonts", pdf.font_families)
		  else
		    # whatever
		end

		page_number = -1
		white_pages.each_with_index do |statements, page|
			page_number = page_number +1
			render_card_page(pdf, card_geometry, card_texts, white_icon_file, deck_name, statements, directory, false, page_number)
			pdf.start_new_page unless page >= white_pages.length-1
		end
		pdf.start_new_page unless white_pages.length == 0 || black_pages.length == 0
		page_number = -1
		black_pages.each_with_index do |statements, page|
			page_number = page_number +1
			render_card_page(pdf, card_geometry, card_texts, black_icon_file, deck_name, statements, directory, true, page_number)
			pdf.start_new_page unless page >= black_pages.length-1
		end

		if output_to_stdout
			puts "Content-Type: application/pdf"
			puts ""
			print pdf.render
		else
			pdf.render_file(output_file)
		end
	end

	if (not input_files_are_absolute) and recurse
		files_in_dir =Dir.glob(directory + File::Separator + "*")
		files_in_dir.each do |subdir|
			if File.directory? subdir
				render_cards(subdir, original_white_file, original_black_file, original_icon_file, deck_name, "irrelevant", false, true, true, card_geometry, card_texts )
			end
		end
	end

end

def parse_args(variables=Hash.new, flags=Hash.new, save_orphaned=false, argv=ARGV)

	parsed_args = Hash.new
	orphaned = Array.new

	new_argv=Array.new
	while argv.length > 0
		next_arg = argv.shift
		if variables.has_key? next_arg
			arg_name = variables[next_arg]
			parsed_args[arg_name] = argv.shift
		elsif flags.has_key? next_arg
			flag_name = flags[next_arg]
			parsed_args[flag_name] = true
		else
			orphaned.push next_arg
		end
		new_argv.push next_arg
	end
	if save_orphaned
		parsed_args["ORPHANED_ARGUMENT_ARRAY"] = orphaned
	end

	while new_argv.length > 0
		argv.push new_argv.shift
	end

	return parsed_args
end






def print_help
	puts "USAGE:"
	puts "\tbbcards --directory [CARD_FILE_DIRECTORY]"
	puts "\tOR"
	puts "\tbbcards --white [WHITE_CARD_FILE] --black [BLACK_CARD_FILE] --icon [ICON_FILE] --output [OUTPUT_FILE]"
	puts ""
	puts "bbcards expects you to specify EITHER a directory or"
	puts "specify a path to black/white card files. If both are"
	puts "specified, it will ignore the indifidual files and generate"
    puts "cards from the directory."
	puts ""
	puts "If you specify a directory, white cards will be loaded from"
    puts "a file white.txt in that directory and black cards from"
	puts "black.txt. If icon.png exists in that directory, it will be"
    puts "used to generate the card icon on the lower left hand side of"
	puts "the card. The output will be a pdf file with the same name as"
	puts "the directory you specified in the current working directory."
	puts "bbcards will descend recursively into any directory you"
	puts "specify, generating a separate pdf for every directory that"
	puts "contains black.txt, white.txt or both."
	puts ""
	puts "You may specify the card size by passing either the --small"
	puts " or --large flag.  If you pass the --small flag then small"
	puts "cards of size 2\"x2\" will be produced. If you pass the --large"
	puts "flag larger cards of size 2.5\"x3.5\" will be produced. Small"
	puts "cards are produced by default."
	puts ""
	puts "All flags:"
	puts "\t-b,--black\t\tBlack card file"
	puts "\t-d,--directory\t\tDirectory to search for card files"
	puts "\t-f,--format\t\tPaper format. Supported: 'LETTER', 'LETTER_' (lanscape), 'DINA4', 'DINA4_' (lanscape)"
	puts "\t-h,--help\t\tPrint this Help message"
	puts "\t-i,--icon\t\tIcon file, should be .jpg or .png"
	puts "\t--lang\t\t\tSelect language por predefined texts. Supported: 'en', 'es'"
	puts "\t-n,--name\t\tDeck name. Default: Cards Against Humanity"
	puts "\t-o,--output\t\tOutput file, will be a .pdf file"
	puts "\t--oneperpage\t\tGenerate one card per page"
	puts "\t-r,--rounded\t\tGenerate cards with rounders corners"
	puts "\t-w,--white\t\tWhite card file"

	puts "\n\tSizes:"
	puts "\t-s,--small\t\tGenerate small 2\"x2\" cards"
	puts "\t-m1,--medium1\t\tGenerate medium 41mm x 63mm cards"
	puts "\t-m2,--medium2\t\tGenerate medium 43mm x 65mm cards"
	puts "\t-m3,--medium3\t\tGenerate medium 45mm x 68mm cards"
	puts "\t-l,--large\t\tGenerate large 2.5\"x3.5\" cards"
	puts ""


end


if not (ENV['REQUEST_URI']).nil?

	require 'cgi'
	cgi = CGI.new( :accept_charset => "UTF-8" )

	white_cards = cgi["whitecards"]
	black_cards = cgi["blackcards"]
	card_size   = cgi["cardsize"]
	page_layout = cgi["pagelayout"]
	icon = "default.png"
	if cgi["icon"] != "default"
		params = cgi.params
		tmpfile = cgi.params["iconfile"].first
		if not tmpfile.nil?
			icon = "/tmp/" + (rand().to_s) + "-" + tmpfile.original_filename
			File.open(icon.untaint, "w") do |f|
    				f << tmpfile.read(1024*1024)
			end
		end
	end


	one_per_page    = page_layout == "oneperpage" ? true : false
	rounded_corners = card_size    == "LR"         ? true : false
	card_geometry   = card_size    == "S" ? get_card_geometry(2.0,2.0,rounded_corners,one_per_page) : get_card_geometry(2.5,3.5,rounded_corners,one_per_page)

	render_cards nil, nil, nil, icon, "", "cards.pdf", true, false, false, card_geometry, get_card_texts(), white_cards, black_cards, true

	if icon != "default.png"
		File.unlink(icon)
	end

else
	arg_defs  = Hash.new
	flag_defs = Hash.new
	arg_defs["-b"]          = "black"
	arg_defs["--black"]     = "black"
	arg_defs["-w"]          = "white"
	arg_defs["--white"]     = "white"
	arg_defs["-d"]          = "dir"
	arg_defs["--directory"] = "dir"
	arg_defs["-i"]          = "icon"
	arg_defs["--icon"]      = "icon"
	arg_defs["-n"]          = "deck_name"
	arg_defs["--name"]      = "deck_name"
	arg_defs["-o"]          = "output"
	arg_defs["--output"]    = "output"
	arg_defs["--lang"]      = "lang"
	arg_defs["-f"]          = "paper_format"
	arg_defs["--format"]    = "paper_format"

	flag_defs["-s"]            = "small"
	flag_defs["--small"]       = "small"
	flag_defs["-m1"]           = "medium41"
	flag_defs["--medium1"]     = "medium41"
	flag_defs["-m2"]           = "medium43"
	flag_defs["--medium2"]     = "medium43"
	flag_defs["-m3"]           = "medium45"
	flag_defs["--medium3"]     = "medium45"
	flag_defs["-l"]            = "large"
	flag_defs["--large"]       = "large"
	flag_defs["-r"]            = "rounded"
	flag_defs["--rounded"]     = "rounded"
	flag_defs["-p"]            = "oneperpage"
	flag_defs["--oneperpage"]  = "oneperpage"
	flag_defs["-h"]            = "help"
	flag_defs["--help"]        = "help"


	args = parse_args(arg_defs, flag_defs)

	lang = args["lang"] || "en"

	if args.has_key? "large"
		card_width_inches  = 2.5
		card_height_inches = 3.5
		card_font_size = 14
	elsif args.has_key? "medium41"
		card_width_inches  = 41/MM_PER_INCH
		card_height_inches = 63/MM_PER_INCH
		card_font_size = 12
	elsif args.has_key? "medium43"
		card_width_inches  = 43/MM_PER_INCH
		card_height_inches = 65/MM_PER_INCH
		card_font_size = 12
	elsif args.has_key? "medium45"
		card_width_inches  = 45/MM_PER_INCH
		card_height_inches = 68/MM_PER_INCH
		card_font_size = 14
	else
		card_width_inches  = 2.0
		card_height_inches = 2.0
		card_font_size = 14
	end
	card_geometry = get_card_geometry( card_width_inches, card_height_inches, card_font_size, args["paper_format"], !(args["rounded"]).nil?, !(args["oneperpage"]).nil? )
	card_texts    = get_card_texts( lang )

    # Set Deck name or use default value
	deck_name = args["deck_name"] || "Cards Against Humanity"

	if args.has_key? "help" or args.length == 0 or ( (not args.has_key? "white") and (not args.has_key? "black") and (not args.has_key? "dir") )
		print_help
	elsif args.has_key? "dir"
		render_cards args["dir"], "white.txt", "black.txt", "icon.png", deck_name, "cards.pdf", false, true, true, card_geometry, card_texts, "", "", false
	else
		render_cards nil, args["white"], args["black"], args["icon"], deck_name, args["output"], true, false, false, card_geometry, card_texts, "", "", false
	end
end
exit


