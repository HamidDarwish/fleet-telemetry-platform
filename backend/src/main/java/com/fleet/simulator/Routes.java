package com.fleet.simulator;

import java.util.List;

/**
 * Predefined closed routes (latitude, longitude) around Kabul used by the virtual vehicles (SIM-2).
 * The coordinates are approximate and only meant for simulation.
 */
public final class Routes {
    private Routes() {}

    public static final List<double[][]> ALL = List.of(
        // central loop
        new double[][]{{34.5281, 69.1723}, {34.5340, 69.1830}, {34.5430, 69.1960},
                       {34.5380, 69.2100}, {34.5260, 69.2000}, {34.5200, 69.1850}},
        // west loop
        new double[][]{{34.5260, 69.1450}, {34.5180, 69.1300}, {34.5050, 69.1250},
                       {34.4950, 69.1350}, {34.5050, 69.1500}, {34.5180, 69.1560}},
        // north-east loop (goes slightly outside the demo geofence)
        new double[][]{{34.5560, 69.2000}, {34.5659, 69.2123}, {34.5700, 69.2300},
                       {34.5600, 69.2400}, {34.5500, 69.2250}, {34.5450, 69.2100}},
        // south loop
        new double[][]{{34.5000, 69.1700}, {34.4900, 69.1850}, {34.4800, 69.1900},
                       {34.4750, 69.1750}, {34.4850, 69.1600}, {34.4950, 69.1650}}
    );
}
