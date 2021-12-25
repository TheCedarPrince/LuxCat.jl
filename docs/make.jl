using Documenter
using LuxCat

makedocs(;
    modules = [LuxCat],
    authors = "Jacob Zelko <jacobszelko@gmail.com> and contributors",
    repo = "https://github.com/TheCedarPrince/LuxCat.jl/blob/{commit}{path}#L{line}",
    sitename = "LuxCat.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        assets = String[],
    ),
    pages = [
        "Home" => "index.md",
    ],
)

deploydocs(; devbranch = "main", repo = "https://github.com/TheCedarPrince/LuxCat.jl.git", push_preview = true)
