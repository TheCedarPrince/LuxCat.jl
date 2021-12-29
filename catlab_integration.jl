using Catlab
using Catlab.Graphs.BasicGraphs
using Colors
using FreeTypeAbstraction
using LaTeXStrings
using Luxor
using MathTeXEngine

import Catlab.CategoricalAlgebra.FreeSchema
import Catlab.CategoricalAlgebra.@acset
import Catlab.CategoricalAlgebra.@acset_type
import Catlab.CategoricalAlgebra.nparts
import Catlab.CategoricalAlgebra.subpart
import Catlab.CategoricalAlgebra.incident

########################
# FUNCTION DEFINITIONS #
########################

"""
    latex_text_size(lstr::LaTeXString)
Returns the width and height of a latex string.
(Credit: Created by Davi Sales Barreira)
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
(Credit: Created by Davi Sales Barreira)
"""
function Luxor.text(
    lstr::LaTeXString,
    pt::Point;
    valign = :baseline,
    halign = :left,
    angle = 0,
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
                    angle = angle,
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

"""
    make_drawing(width, height, img_path, bkg_color, origin_p)

Creates a Luxor `Drawing` object with given width and height dimensions.
Saves the image to whatever path of choosing.
Allows one to set the background color of an image.
Finally, one can set Luxor's reference origin point
"""
function make_drawing(width, height, img_path, bkg_color, origin_p)
    d = Drawing(width, height, img_path)
    background(bkg_color)
    origin(origin_p)
    return d
end

"""
Converts a coordinate pair in the traditional Cartesian coordinate system to a `Point` in Luxor's coordinate system.
"""
cart2luxor(p) = Point(p.x, -p.y)
cart2luxor(p::Array) = Point(p[1], -p[2])
cart2luxor(x, y) = Point(x, -y)

"""
Converts a Luxor `Point` to a coordinate pair in the traditional Cartesian coordinate system.
"""
luxor2cart(p::Point) = [p.x, -p.y]

"""
Finds points along the parametric representation of a given line.
"""
parametric_point(t, x, y) = x + y * t

"""
Draws text at a given location along a morphism
"""
function morphtext(
    label1::Any,
    label2::Any;
    offset1::Real = 20,
    offset2::Real = 20,
    angle = 0,
    size = nothing,
)
    fontsize(size)
    text(label1, cart2luxor(0, offset1), valign = :middle, halign = :center, angle = angle)
    text(label2, cart2luxor(0, -offset2), valign = :middle, halign = :center, angle = angle)
end

function morphtext(label::Any; offset::Real = 20, angle = 0, size = nothing)
    fontsize(size)
    text(label, cart2luxor(0, offset), valign = :middle, halign = :center, angle = angle)
end

"""
Draws a single morphism between two objects.
"""
function morphism(
    initial_point::Array,
    terminal_point::Array;
    label1::Any = "",
    label2::Any = "",
    offset1::Real = 10,
    offset2::Real = 10,
    size::Real = 16,
    padding::Real = 0.15,
)

     v⃗ = terminal_point .- initial_point
       θ = atan(v⃗[2] / v⃗[1]) + (v⃗[1] < 0 ? π : 0)

    padded_initial_point =
        between(cart2luxor(initial_point), cart2luxor(terminal_point), padding)
    padded_terminal_point =
        between(cart2luxor(initial_point), cart2luxor(terminal_point), 1 - padding)

    arrow(
        padded_initial_point,
        padded_terminal_point,
        arrowheadlength = 15,
        decoration = 0.5,
        decorate = () -> morphtext(
            label1,
            label2,
            offset1 = offset1,
            offset2 = offset2,
            angle = θ,
            size = size,
        ),
        linewidth = 3,
    )

end

"""
Draws two morphism between two objects.
Morphisms can face different directions and be styled differently.
"""
function morphism(
    initial_point_1::Array,
    terminal_point_1::Array,
    initial_point_2::Array,
    terminal_point_2::Array;
    label1::Any = "",
    label2::Any = "",
    style1::String = "solid",
    style2::String = "solid",
    offset1::Real = 10,
    offset2::Real = 10,
    size::Real = 16,
    padding::Real = 0.15,
)

    Set([initial_point_1, terminal_point_1]) != Set([initial_point_2, terminal_point_2]) &&
        @error "Only two different points allowed"

    padded_is = []
    padded_ts = []
    angles = []
    for (i, t) in [[initial_point_1, terminal_point_1], [initial_point_2, terminal_point_2]]
         v⃗ = t .- i
           θ = atan(v⃗[2] / v⃗[1]) + (v⃗[1] < 0 ? π : 0)

        padded_i = between(cart2luxor(i), cart2luxor(t), padding)
        padded_t = between(cart2luxor(i), cart2luxor(t), 1 - padding)

         v⃗ₚ = luxor2cart(padded_i) .- luxor2cart(padded_t)
        x = 1
        y = 1
          if (-1 * v⃗ₚ[1] * x) / v⃗ₚ[2] |> isinf
              x = (v⃗ₚ[2] * y) / (-1 * v⃗ₚ[1])
        else
              y = (-1 * v⃗ₚ[1] * x) / v⃗ₚ[2]
        end
        i_new = parametric_point(
            length(padded_is) == 0 ? 10 : -10,
            luxor2cart(padded_i),
            [x; y],
        )
        t_new = parametric_point(
            length(padded_ts) == 0 ? 10 : -10,
            luxor2cart(padded_t),
            [x; y],
        )
        push!(padded_is, i_new)
        push!(padded_ts, t_new)
        push!(angles, θ)
    end

    setdash(style1)

    arrow(
        cart2luxor(padded_is[1]),
        cart2luxor(padded_ts[1]),
        arrowheadlength = 15,
        decoration = 0.5,
        decorate = () ->
            morphtext(label1, offset = offset1 + 20, angle = angles[1], size = size),
        linewidth = 3,
    )

    setdash(style2)

    arrow(
        cart2luxor(padded_is[2]),
        cart2luxor(padded_ts[2]),
        arrowheadlength = 15,
        decoration = 0.5,
        decorate = () ->
            morphtext(label2, offset = -offset2 - 10, angle = angles[2], size = size),
        linewidth = 3,
    )

    setdash("solid")

end

"""
Draws a Commutative Diagram of a given graph
"""
function commutative_diagram(C; offset::Real = 30, size::Real = 20, padding::Real = 0.15)

    fontsize(20)
    sethue("white")
    for i in 1:nparts(C, :V)
	p = C[i, :loc]
	text(C[i, :v_labels], cart2luxor(p), valign = :middle, halign = :center)
    end

    for i in 1:nparts(C, :E)
        initial_point = C[i, :src] |> s -> C[s, :loc]
	terminal_point = C[i, :tgt] |> s -> C[s, :loc]
	 v⃗ = terminal_point .- initial_point
	   θ = atan(v⃗[2] / v⃗[1]) + (v⃗[1] < 0 ? π : 0)

	padded_initial_point =
	    between(cart2luxor(initial_point), cart2luxor(terminal_point), padding)
	padded_terminal_point =
	    between(cart2luxor(initial_point), cart2luxor(terminal_point), 1 - padding)

	arrow(
	    padded_initial_point,
	    padded_terminal_point,
	    arrowheadlength = 15,
	    decoration = 0.5,
	    decorate = () -> morphtext(C[i, :e_labels], offset = offset, angle = θ, size = size),
	    linewidth = 3,
	)
    end

end

#############
# CONSTANTS #
#############

width = 500
height = 500
path = "catlab_integration.png"
color = RGBA(0.0, 0.0, 0.0)
op = Point(width / 2, height / 2)

p1 = [-125, 125] # Top left quadrant
p2 = [125, 125] # Top right quadrant
p3 = [-125, -125] # Bottom left quadrant
p4 = [125, -125] # Bottom right quadrant

########
# MAIN #
########


my_draw = make_drawing(width, height, path, color, op)

@present TheoryGraph(FreeSchema) begin
    V::Ob
    E::Ob
    src::Hom(E, V)
    tgt::Hom(E, V)
    T::AttrType
    loc::Attr(V, T)
    v_labels::Attr(V, T)
    e_labels::Attr(E, T)
end

@acset_type Graph(TheoryGraph, index = [:src, :tgt])

g = @acset Graph{Any} begin
    V = 4
    E = 5
    src = [1, 1, 2, 2, 3]
    tgt = [2, 3, 3, 4, 4]
    loc = [p1, p2, p3, p4]
    v_labels = [L"A", L"A", L"B", L"B"]
    e_labels = [L"id_{A}", L"f", L"f", L"f", L"id_{B}"]
end

commutative_diagram(g; padding = .1)

finish()
