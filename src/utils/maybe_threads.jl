macro maybe_threads(cond, loop)
    return esc(
        quote
            if $cond
                $Threads.@sync $(Expr(:for, loop.args[1], :($Threads.@spawn $(loop.args[2]))))
            else
                $loop
            end
        end
    )
end
