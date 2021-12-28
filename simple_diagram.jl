using Colors
using FreeTypeAbstraction
using LaTeXStrings
using Luxor
using MathTeXEngine

"""
    latex_text_size(lstr::LaTeXString)
Returns the width and height of a latex string.
"""
function latex_text_size(lstr::LaTeXString)
    sentence = generate_tex_elements(lstr)
    els = filter(x -> x[1] isa TeXChar, sentence)
    chars = [x[1].char for x in els]
    fonts = [x[1].font for x in els]
    pos_x = [x[2][1] for x in els]
    pos_y = [x[2][2] for x in els]
    scales = [x[3] for x in els]
    extents = [FreeTypeAbstraction.get_extent(f, c) for (f, c) in zip(fonts, chars)]

    textw = []
    texth = []
    for i = 1:length(extents)
        textw = push!(
            textw,
            FreeTypeAbstraction.height_insensitive_boundingbox(
                extents[i],
                fonts[i],
            ).widths[1] * scales[i] + pos_x[i],
        )
        texth = push!(
            texth,
            FreeTypeAbstraction.height_insensitive_boundingbox(
                extents[i],
                fonts[i],
            ).widths[2] * scales[i] - pos_y[i],
        )
    end
    return (maximum(textw), maximum(texth))
end

"""
    Luxor.text(lstr::LaTeXString, valign=:baseline, halign=:left; kwargs...)
Draws LaTeX string using `MathTexEngine.jl`. Hence, uses ModernCMU as font family.
Note that `valign` is not perfect.
This function assumes that the axis are in the standard Luxor directions,
i.e. ↓→.
"""
function Luxor.text(
    lstr::LaTeXString,
    pt::Point;
    valign = :baseline,
    halign = :left,
    angle = 0
)

    # Function from MathTexEngine
    sentence = generate_tex_elements(lstr)

    # Get current font size.
    textsize = get_fontsize()

    textw, texth = latex_text_size(lstr)

    if halign === :left
        translate_x = 0
    elseif halign === :right
        translate_x = -textw * textsize
    elseif halign === :center
        translate_x = -textw / 2 * textsize
    end

    if valign === :baseline
        translate_y = 0
    elseif valign === :top
        translate_y = -textsize
    elseif valign === :bottom
        translate_y = texth * textsize
    elseif valign === :middle
        translate_y = textsize / 2
    end

    # Writes text using ModernCMU font.
    for text in sentence
        if text[1] isa TeXChar
            @layer begin
                translate(translate_x, translate_y)
		fontface(text[1].font.family_name)
                fontsize(textsize * text[3])
                Luxor.text(
                    string(text[1].char),
                    pt + Point(text[2]...) * textsize * (1, -1),
		    angle = angle
                )
            end
        elseif text[1] isa HLine
            @layer begin
                translate(translate_x, translate_y)
                pointstart = pt + Point(text[2]...) * textsize * (1, -1)
                pointend = pointstart + Point(text[1].width, 0) * textsize
                setline(1 * text[1].thickness * textsize)
                line(pointstart, pointend, :stroke)
            end
        end
    end
end

# Auxiliary drawing functions
function make_drawing(width, height, img_path, bkg_color, origin_p)
    d = Drawing(width, height, img_path)
    background(bkg_color)
    origin(origin_p)
    return d
end

map2luxor(p) = Point(p.x, -p.y)
map2luxor(p::Array) = Point(p[1], -p[2])
map2luxor(x, y) = Point(x, -y)

# Constants
## Canvas constants
width = 500
height = 500
path = "simple_diagram.png"
color = RGBA(0.0, 0.0, 0.0)
op = Point(width / 2, height / 2)

# Setting up drawing
my_draw = make_drawing(width, height, path, color, op)

sethue(RGBA(1.0, 1.0, 1.0))

p1 = [-125, 125] # Top left quadrant
p2 = [125, 125] # Top right quadrant
p3 = [-125, -125] # Bottom left quadrant
p4 = [125, -125] # Bottom right quadrant

function morphtext(;
    label1::Any,
    label2::Any,
    offset1::Real,
    offset2::Real,
    angle,
    size = nothing,
)
    fontsize(size)
    text(label1, map2luxor(0, offset1), valign = :middle, halign = :center, angle = angle)
    text(label2, map2luxor(0, -offset2), valign = :middle, halign = :center, angle = angle)
end

# text(L"9\frac{3}{4}", O)

function morphism(;
    initial_point::Array = nothing,
    terminal_point::Array = nothing,
    label1::Any = "",
    label2::Any = "",
    offset1::Real = 10,
    offset2::Real = 10,
    size::Real = 16,
    padding::Real = .15
)

     v⃗ = terminal_point .- initial_point
       θ = atan(v⃗[2] / v⃗[1]) + (v⃗[1] < 0 ? π : 0)

    padded_initial_point =
        between(map2luxor(initial_point), map2luxor(terminal_point), padding)
    padded_terminal_point =
        between(map2luxor(initial_point), map2luxor(terminal_point), 1 - padding)

    arrow(
        padded_initial_point,
	padded_terminal_point,
        arrowheadlength = 15,
        decoration = 0.5,
        decorate = () -> morphtext(;
            label1 = label1,
            label2 = label2,
            offset1 = offset1,
            offset2 = offset2,
            angle = θ,
            size = size,
        ),
        linewidth = 3,
    )

end

morphism(initial_point = p1, terminal_point = p2, label1 = L"f", offset1 = 20)
morphism(initial_point = p2, terminal_point = p4, label1 = L"F", offset1 = 20)
morphism(initial_point = p1, terminal_point = p3, label2 = L"F", offset2 = 20)
morphism(initial_point = p3, terminal_point = p4, label2 = L"F(f)", offset2 = 20)
morphism(initial_point = p1, terminal_point = p4, label1 = L"ID", offset1 = 20)

sethue(RGBA(1.0, 1.0, 1.0))
fontsize(24)
text(L"A", map2luxor(p1), valign = :middle, halign = :center)
text(L"B", map2luxor(p2), valign = :middle, halign = :center)
text(L"F(A)", map2luxor(p3), valign = :middle, halign = :center)
text(L"F(B)", map2luxor(p4), valign = :middle, halign = :center)

finish()
