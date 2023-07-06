function update_plots(; sol, menu_color, menu_abiotic, axes, cb)
    trait = menu_color.selection.val
    name_index = getindex.([menu_color.options.val...], 2) .== trait
    trait_name = first.([menu_color.options.val...])[name_index][1]


    color = nothing
    if trait == :biomass
        color = ustrip.(species_biomass(sol.biomass))
    else
        color = ustrip.(sol.p.species[trait])
    end

    colormap = :viridis
    colorrange = (minimum(color), maximum(color))

    cb.colormap = colormap
    cb.colorrange = colorrange
    cb.label = trait_name

    empty!(axes[1])
    band_patch(axes[1]; patch=1, sol, color, colormap, colorrange)

    empty!(axes[5])
    growth_rates(axes[5]; patch=1, sol, color, colormap, colorrange)

    empty!(axes[2])
    if menu_color.selection.val != :biomass
        trait_mean_biomass(trait, trait_name, axes[2]; sol, color, colormap, colorrange)
    else
        axes[2].xlabel = ""
        autolimits!(axes[2])
    end

    empty!(axes[4])
    my_set = Dict(:markersize=>4, :linewidth=>0.1)
    scatterlines!(axes[4], sol.t ./ 365, ustrip.(sol.water[:, 1]);
        color=:turquoise3,
        my_set...)
    axes[4].ylabel="Soil water [mm]"
    axes[4].xlabel="Time [years]"
    ylims!(axes[4], 0.0, nothing)


    ########### Abiotic plot
    abiotic_colors = [:blue, :brown, :red, :red, :orange]
    abiotic = menu_abiotic.selection.val
    name_index = getindex.([menu_abiotic.options.val...], 2) .== abiotic
    abiotic_name = first.([menu_abiotic.options.val...])[name_index][1]
    abiotic_color = abiotic_colors[name_index][1]

    empty!(axes[6])
    scatterlines!(axes[6], sol.t[2:end] ./ 365, ustrip.(sol.p.env_data[abiotic]);
        color=abiotic_color,
        my_set...)
    axes[6].ylabel=abiotic_name
    axes[6].xlabel="Time [years]"

    return nothing
end


function dashboard(sim, input_prep_fun;)
    fig = Figure(; resolution=(1500, 900))

    top_menu = fig[1,1] = GridLayout()
    plots_layout = fig[2,1] = GridLayout()

    menu_layout = top_menu[1,2] = GridLayout()
    mowing_layout = top_menu[1,3] = GridLayout()
    grazing_layout = top_menu[1,4] = GridLayout()
    nutrient_layout = top_menu[1,5] = GridLayout()
    right_layout = top_menu[1,6] = GridLayout()

    run_button = Button(top_menu[1,1]; label="run")

    # [Box(top_menu[1,i], color = (:red, 0.2), strokevisible=false) for i in 1:6]

    ############# Exploratory
    Label(menu_layout[1,1], "Exploratory";
        tellwidth=false, halign=:left)
    menu_explo = Menu(menu_layout[2,1], options = zip([
        "Schorfheide-Chorin",
        "Hainich",
        "Schwäbische Alb"
    ], ["SCH", "HAI", "ALB"])
    )

    ############# Coloring -> traits or biomass
    Label(menu_layout[3,1], "Color/trait (right upper plot)";
        tellwidth=false, halign=:left)
    menu_color = Menu(menu_layout[4,1], options = zip([
        "Specific leaf area [m² g⁻¹]",
        "Leaf nitrogen per leaf mass [mg g⁻¹]",
        "Height [m]",
        "Leaf life span [d]",
        "Mycorrhizal colonisation",
        "Root surface area /\nabove ground biomass [m² g⁻¹]",
        # "Mowing effect λ\n(part that is removed)", :λ,
        "Biomass"
    ], [:SLA, :LNCM, :CH, :LL, :AMC, :SRSA_above, :biomass])
    )

    ############# Abiotic variable
    Label(menu_layout[5,1], "Abiotic variable (right lower plot)";
        tellwidth=false, halign=:left)
    menu_abiotic = Menu(menu_layout[6,1], options = zip([
        "Precipitation [mm d⁻¹]",
        "Potential evapo-\ntranspiration [mm d⁻¹]",
        "Air temperature [°C]\n",
        "Air temperaturesum [°C]\n",
        "Photosynthetically active\nradiation [MJ m⁻² d⁻¹]"
    ], [
        :precipitation,
        :PET,
        :temperature,
        :temperature_sum,
        :PAR
    ])
    )
    [rowgap!(menu_layout, i, dist) for (i, dist) in enumerate([5,15,5,15,5])]

    ############# Mowing
    Label(mowing_layout[1,1:2], "Mowing (date)";
        tellwidth=true, halign=:left)
    toggles_mowing = [
        Toggle(mowing_layout[i+1, 1],
            active = false, halign=:left) for i in 1:5]
    tb_mowing_date = [Textbox(mowing_layout[i+1, 2],
        halign=:left,
        placeholder=mow_date, validator=test_date,
        stored_string=mow_date) for (i,mow_date) in enumerate(
            ["05-01","06-01", "07-01", "08-01", "09-01"])
    ]
    [rowgap!(mowing_layout, i, 4) for i in 1:5]
    colgap!(mowing_layout, 1, 10)

    ############# Grazing
    Label(grazing_layout[1,1:4], "Grazing (start date, end date, LD)";
        halign=:left)
    toggles_grazing = [
        Toggle(grazing_layout[i+1, 1], active = false) for i in 1:2]
    tb_grazing_start = [Textbox(grazing_layout[i+1, 2],
        placeholder=graz_start, validator=test_date,
        stored_string=graz_start) for (i,graz_start) in enumerate(["05-01","08-01"])]
    tb_grazing_end = [Textbox(grazing_layout[i+1, 3],
        placeholder=graz_end, validator=test_date,
        stored_string=graz_end) for (i,graz_end) in enumerate(["07-01","10-01"])]
    tb_grazing_intensity = [Textbox(grazing_layout[i+1, 4],
        placeholder=string(intensity), validator=Float64,
        stored_string=string(intensity)) for (i,intensity) in enumerate([2, 2])]
    [rowgap!(grazing_layout, i, 4) for i in 1:2]
    [colgap!(grazing_layout, i, 10) for i in 1:3]

    ############# Nutrients
    slidergrid_nut = SliderGrid(
        nutrient_layout[1,1],
        (label = "Nutrient\nindex", range = 0.0:0.01:1.0, format = "{:.1f}", startvalue = 0.8),
        tellheight = false)
    slider_nut = slidergrid_nut.sliders[1]

    ############# Number of years
    Label(right_layout[1,1], "Number of years";
        tellwidth=false, halign=:right)
    nyears = Observable(2)
    tb_years = Textbox(right_layout[1, 2],
        placeholder=string(nyears.val),
        stored_string=string(nyears.val),
        validator=Int64)

    on(tb_years.stored_string) do s
        nyears[] = parse(Int64, s)
    end

    ############# Number of species
    Label(right_layout[2,1], "Number of species";
        tellwidth=false, halign=:right)
    nspecies = Observable(25)
    tb_species = Textbox(right_layout[2, 2],
        placeholder=string(nspecies.val),
        stored_string=string(nspecies.val),
        validator=Int64)

    on(tb_species.stored_string) do s
        nspecies[] = parse(Int64, s)
    end


    ###########
    Label(right_layout[3,1], "include water reduction?";
        tellwidth=true, halign=:right)
    toggle_water_red = Toggle(
        right_layout[3, 2],
        active = true
    )

    Label(right_layout[4,1], "include nutrient reduction?";
        tellwidth=true, halign=:right)
    toggle_nutr_red = Toggle(
        right_layout[4, 2],
        active = true
    )
    rowgap!(right_layout, 1, 5)
    rowgap!(right_layout, 3, 5)
    colgap!(right_layout, 1, 5)
    # colsize!(right_layout, 1, 200)

    axes = [
        Axis(
            plots_layout[u,i];
            backgroundcolor=(:grey, i+(u-1)*3 .∈ Ref([1,4]) ? 0.1 : 0.0),
            alignmode = Outside())
            for i in 1:3, u in 1:2
    ]
    delete!(axes[3])

    cb = Colorbar(plots_layout[1,3];
        colorrange=(-0.5, 0.5),
        halign=:left,
        # alignmode = Outside(),
        tellwidth=false)

    ########### size adjustments
    colsize!(top_menu, 2, 300)
    [colgap!(top_menu, i, 15)  for i in 1:5]
    colgap!(top_menu, 4, 35)

    ###########
    sol = nothing

    still_running = false


    on(run_button.clicks) do n

        if !still_running
            still_running = true

            # ------------- mowing
            mowing_selected = [toggle.active.val for toggle in toggles_mowing]
            mowing_dates = [tb.stored_string.val for tb in tb_mowing_date][mowing_selected]

            ## final vectors of vectors
            day_of_year_mowing = Dates.dayofyear.(Dates.Date.(mowing_dates, "mm-dd"))
            mowing_days = [day_of_year_mowing for _ in 1:nyears.val]
            mowing_heights = deepcopy(mowing_days)
            [mowing_heights[n][:] .= 7 for n in 1:nyears.val]

            # ------------- grazing
            grazing_selected = [toggle.active.val for toggle in toggles_grazing]
            grazing_start = [
                tb.stored_string.val for tb in tb_grazing_start
            ][grazing_selected]
            grazing_end = [
                tb.stored_string.val for tb in tb_grazing_end
            ][grazing_selected]
            grazing_intensity = [
                parse(Float64, tb.stored_string.val)
                for tb in tb_grazing_intensity
            ][grazing_selected]

            # ------------- soil nutrients
            nutrient_index = slider_nut.value.val

            water_reduction = toggle_water_red.active.val
            nutrient_reduction = toggle_nutr_red.active.val

            input_obj = input_prep_fun(;
                nyears=nyears.val,
                nspecies=nspecies.val,
                explo=menu_explo.selection.val,
                mowing_heights,
                mowing_days,
                nutrient_index,
                grazing_start,
                grazing_end,
                grazing_intensity,
                water_reduction,
                nutrient_reduction)

            sol = sim.solve_prob(; input_obj)

            update_plots(; sol, menu_color, menu_abiotic, axes, cb)
            still_running = false
        end
    end

    on(menu_color.selection) do n
        if !isnothing(sol)
            update_plots(; sol, menu_color, menu_abiotic, axes, cb)
        end
    end

    on(menu_abiotic.selection) do n
        if !isnothing(sol)
            update_plots(; sol, menu_color, menu_abiotic, axes, cb)
        end
    end

    run_button.clicks[] = 1

    return fig
end
