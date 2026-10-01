"""
    Page

A rendered dashboard page before it is wrapped in the document shell.

Fields
- `title::String`: Browser tab title.
- `crumbs::Vector`: Breadcrumb trail as `label => href` pairs; the current page has `nothing`.
- `body::Vector{Any}`: DOM nodes placed inside the main column.
- `live::Bool`: `true` when the page should refresh itself while iterations are running.
- `status::Int`: HTTP status the page is served with.
- `chrome::Bool`: `false` for pages rendered without the top bar and footer (sign-in).
"""
struct Page
    title::String
    crumbs::Vector
    body::Vector{Any}
    live::Bool
    status::Int
    chrome::Bool
end

function Page(
    title::AbstractString,
    crumbs::AbstractVector,
    body::AbstractVector;
    live::Bool=false,
    status::Integer=200,
    chrome::Bool=true,
)
    return Page(
        String(title), collect(crumbs), collect(Any, body), live, Int(status), chrome
    )
end

"""
    PageContext

What a page needs to know about the request it answers.

Fields
- `viewer::User`: The signed-in user (or the seeded default when auth is off).
- `path::String`: Request path, used to mark the active navigation entry.
- `query::Dict{String,String}`: Query parameters, used for one-shot notices after a form.
- `csrf::String`: Token embedded in every form on the page.
"""
struct PageContext
    viewer::User
    path::String
    query::Dict{String,String}
    csrf::String
end

function PageContext(
    viewer::User;
    path::AbstractString="/",
    query=Dict{String,String}(),
    csrf::AbstractString="",
)
    return PageContext(viewer, String(path), query, String(csrf))
end

"""
    Access

What the viewer may do to the records of one project, mirroring the REST middlewares:
administrators may do everything, members need the matching project permission.
"""
struct Access
    update::Bool
    create::Bool
    delete::Bool
end
