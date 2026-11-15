$caravanTravelDurationMultiplier = 0.01
function Set-FasterRegionTravel_ModInfo {
    # Process will use first available: HERE, existing ModInfo.json (auto-versioning), lastly as generic defaults
    return @{
        # id          = "phrontisteries.FasterRegionTravel"
        # name        = "Faster Region Travel"
        description = @"
Speed of travel "caravans" in the region, multiplier: $caravanTravelDurationMultiplier
"@
        # author      = "phrontisteries"
        # modVersion  = "0.99.99.99"
        # gameVersion = "1.0.46"
        tags        = @("General")
    }
}
function Build-FasterRegionTravel_DateTimeSettings {
    param( [Parameter(Mandatory)]$RawJson )

    # Deep copy so we never mutate the inbound object
    $out = $RawJson.PSObject.Copy()

    # --- Update each seasons[*].caravanTravelDurationMultiplier -----------------------
    foreach ($season in $out.seasons) {
        $season.caravanTravelDurationMultiplier = $caravanTravelDurationMultiplier
    }

    return $out
}

