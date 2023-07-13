function grazing(sim;
    grazing_factor=1,
    path=nothing)

    fig = Figure(; resolution=(800, 400))
    Axis(fig[1,1],
        xlabel="Total biomass [green dry mass kg ha⁻¹]",
        ylabel="Grazed biomass (graz)\n[green dry mass kg ha⁻¹ d⁻¹]",
        title="")

    nspecies = 3
    nbiomass = 500

    LD = 2u"ha ^ -1"
    biomass_vec = LinRange(0, 1000, nbiomass)u"kg / ha"
    ρ = [0.9, 1.0, 1.2]

    grazing_mat = Array{Float64}(undef, nspecies, nbiomass)

    for (i,biomass) in enumerate(biomass_vec)
        graz = sim.Growth.grazing(;
                LD,
                biomass=repeat([biomass], 3),
                ρ,
                grazing_factor,
                nspecies
        )
        grazing_mat[:, i] = ustrip.(graz)
    end


    for i in 1:nspecies
        lines!(ustrip.(biomass_vec) .* 3, grazing_mat[i, :];
            linewidth=3, label="ρ=$(ρ[i])")
    end

    lines!(ustrip.(biomass_vec) .* 3, vec(sum(grazing_mat, dims=1));
        color=:grey,
        markersize=10,
        label="total")

    axislegend(; framevisible=false, position=:lt)

    if !isnothing(path)
        save(path, fig;)
    else
        display(fig)
    end

    return nothing
end


function trampling(sim;
    nspecies = 5,
    nLD = 500,
    biomass = fill(100.0, nspecies)u"kg / ha",
    LDs = LinRange(0.0, 4.0, nLD)u"ha^-1",
    trampling_factor=0.04,
    path=nothing)

    fig = Figure(; resolution=(800, 400))

    ## ----------- Influence of LA
    ax1 = Axis(fig[1,1],
        xlabel="Livestock density [ha⁻¹]",
        ylabel="Proportion of biomass that is\nremoved by trampling [d⁻¹]",
        title="Influence of the leaf area")
    LA = reverse([100.0, 200.0, 500, 700, 10_000.0] .* u"mm^2")
    CH = fill(0.25, nspecies)u"m"
    trampling_mat_LA = Array{Float64}(undef, nspecies, nLD)
    for (i,LD) in enumerate(LDs)
        trampled_biomass = sim.
            Growth.trampling(; LD, biomass, LA, CH, nspecies, trampling_factor)
            trampling_mat_LA[:, i] = ustrip.(trampled_biomass)
    end
    trampling_mat_LA = trampling_mat_LA ./ 100.0
    for i in 1:nspecies
        lines!(ustrip.(LDs), trampling_mat_LA[i, :];
            linewidth=3, label="LA=$(Int(round(ustrip(LA[i])))) mm²",
            colormap=:viridis,
            colorrange=(1, nspecies),
            color=i)
    end
    axislegend(; framevisible=false, position=:lt)

    ## ----------- Influence of CH
    ax2 = Axis(fig[1,2],
        xlabel="Livestock density [ha⁻¹]",
        yticklabelsvisible=false,
        title="Influence of the plant height")
    LA = fill(500.0)u"mm^2"
    CH = reverse([0.1, 0.2, 0.5, 0.8, 1.0]u"m")
    trampling_mat_CH = Array{Float64}(undef, nspecies, nLD)
    for (i,LD) in enumerate(LDs)
        trampled_biomass = sim.
            Growth.trampling(; LD, biomass, LA, CH, nspecies, trampling_factor)
            trampling_mat_CH[:, i] = ustrip.(trampled_biomass)
    end
    trampling_mat_CH = trampling_mat_CH ./ 100.0
    for i in 1:nspecies
        lines!(ustrip.(LDs), trampling_mat_CH[i, :];
            linewidth=3, label="CH=$(CH[i])",
            colormap=:viridis,
            colorrange=(1, nspecies),
            color=i)
    end
    axislegend(; framevisible=false, position=:lt)


    max_trampling = max(maximum(trampling_mat_LA), maximum(trampling_mat_CH))

    ylims!(ax1, -0.002, 1.1 * max_trampling)
    ylims!(ax2, -0.002, 1.1 * max_trampling)
    colgap!(fig.layout, 1, 5)

    if !isnothing(path)
        save(path, fig;)
    else
        display(fig)
    end

    return nothing
end


function trampling_combined(sim;
    LA,
    CH,
    nspecies = 5,
    biomass = fill(100.0, nspecies)u"kg / ha",
    nLD = 500,
    LDs = LinRange(0.0, 4.0, nLD)u"ha^-1",
    path=nothing)

    species_order = sortperm(ustrip.(LA); rev=true)
    LA = LA[species_order]
    CH = CH[species_order]

    fig = Figure(; resolution=(700, 500))

    ## ----------- Influence of LA
    ax1 = Axis(fig[1,1],
        xlabel="Livestock density [ha⁻¹]",
        ylabel="Proportion of biomass that is\nremoved by trampling [d⁻¹]",
        title="Influence of the leaf area")

    trampling_mat_LA = Array{Float64}(undef, nspecies, nLD)
    for (i,LD) in enumerate(LDs)
        trampled_biomass = sim.
            Growth.trampling(; LD, biomass, LA, CH, nspecies)
            trampling_mat_LA[:, i] = ustrip.(trampled_biomass)
    end
    trampling_mat_LA = trampling_mat_LA ./ 100.0
    for i in 1:nspecies
        lines!(ustrip.(LDs), trampling_mat_LA[i, :];
            linewidth=3,
            label="LA=$(Int(round(ustrip(LA[i])))) mm², CH=$(round(ustrip(CH[i]), digits=2))m",
            color=i,
            colorrange=(1, nspecies))
    end
    axislegend(; framevisible=false, position=:lt, labelsize=14)


    if !isnothing(path)
        save(path, fig;)
    else
        display(fig)
    end

    return nothing
end


function mowing(sim;
    nspecies = 3,
    nbiomass = 3,
    biomass_vec = LinRange(0, 1000, nbiomass),
    CH = [0.5, 0.3, 0.1]u"m",
    mowing_height=7,
    mowing_factor=1.0,
    days_since_last_mowing=100,
    path=nothing)

    fig = Figure(; resolution=(800, 400))
    Axis(fig[1,1],
        xlabel="Total biomass [green dry mass kg ha⁻¹]",
        ylabel="Maximal amount of biomass that is\nremoved by mowing (mow)\n[green dry mass kg ha⁻¹ d⁻¹]",
        title="")


    mowing_mat = Array{Float64}(undef, nspecies, nbiomass)

    for (i,biomass) in enumerate(biomass_vec)
        mow =
            sim.Growth.mowing(;
                biomass=repeat([biomass], nspecies),
                CH,
                mowing_height,
                mowing_factor,
                days_since_last_mowing
        )
        mowing_mat[:, i] = ustrip.(mow)
    end


    for i in 1:nspecies
        lines!(biomass_vec .* nspecies, mowing_mat[i, :];
            linewidth=3, label="CH=$(CH[i])",
            color=i,
            colorrange=(1, nspecies))
    end

    if nspecies <= 5
        lines!(biomass_vec .* nspecies, vec(sum(mowing_mat, dims=1));
            color=:grey,
            markersize=10,
            label="total")
    end

    axislegend(; framevisible=false, position=:lt)

    if !isnothing(path)
        save(path, fig;)
    else
        display(fig)
    end

    return nothing
end
