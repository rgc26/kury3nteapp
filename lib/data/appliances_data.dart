import 'package:flutter/material.dart';
import '../models/app_models.dart';

/// Common Filipino household appliances with typical wattage values
List<Appliance> getDefaultAppliances() {
  return [
    Appliance(name: 'Window Aircon', icon: Icons.ac_unit, defaultWattage: 1000),
    Appliance(name: 'Inverter Aircon', icon: Icons.ac_unit, defaultWattage: 600),
    Appliance(name: 'Refrigerator', icon: Icons.kitchen, defaultWattage: 150),
    Appliance(name: 'Inverter Ref', icon: Icons.kitchen, defaultWattage: 80),
    Appliance(name: 'Electric Fan', icon: Icons.wind_power, defaultWattage: 75),
    Appliance(name: 'Ceiling Fan', icon: Icons.wind_power, defaultWattage: 65),
    Appliance(name: 'LED TV 32"', icon: Icons.tv, defaultWattage: 35),
    Appliance(name: 'LED TV 50"', icon: Icons.tv, defaultWattage: 70),
    Appliance(name: 'Desktop PC', icon: Icons.computer, defaultWattage: 300),
    Appliance(name: 'Laptop', icon: Icons.laptop, defaultWattage: 65),
    Appliance(name: 'WiFi Router', icon: Icons.router, defaultWattage: 12),
    Appliance(name: 'Rice Cooker', icon: Icons.rice_bowl, defaultWattage: 400),
    Appliance(name: 'Microwave Oven', icon: Icons.microwave, defaultWattage: 1000),
    Appliance(name: 'Flat Iron', icon: Icons.iron, defaultWattage: 1000),
    Appliance(name: 'Washing Machine', icon: Icons.local_laundry_service, defaultWattage: 500),
    Appliance(name: 'Water Pump', icon: Icons.water_drop, defaultWattage: 750),
    Appliance(name: 'Water Heater', icon: Icons.hot_tub, defaultWattage: 1500),
    Appliance(name: 'Electric Stove', icon: Icons.outdoor_grill, defaultWattage: 1500),
    Appliance(name: 'LED Light Bulb', icon: Icons.lightbulb, defaultWattage: 10),
    Appliance(name: 'Phone Charger', icon: Icons.phone_android, defaultWattage: 18),
    Appliance(name: 'Hair Dryer', icon: Icons.air, defaultWattage: 1200),
    Appliance(name: 'Electric Kettle', icon: Icons.coffee, defaultWattage: 1500),
    Appliance(name: 'Oven Toaster', icon: Icons.countertops, defaultWattage: 800),
    Appliance(name: 'Blender', icon: Icons.blender, defaultWattage: 350),
  ];
}

/// Meralco electricity rate tiers (as of May 2026, approximate)
class MeralcoRates {
  // Total effective rate per kWh (generation + transmission + distribution + others)
  static const double ratePerKwh = 11.8569; // approximate Meralco rate

  static double getEffectiveRate(double monthlyKwh) {
    if (monthlyKwh <= 20) return 4.1326;
    if (monthlyKwh <= 50) return 5.2936;
    if (monthlyKwh <= 100) return 8.3210;
    if (monthlyKwh <= 200) return 10.2845;
    return ratePerKwh;
  }

  static double calculateMonthlyBill(double monthlyKwh) {
    return monthlyKwh * getEffectiveRate(monthlyKwh);
  }

  static String getRateTier(double monthlyKwh) {
    if (monthlyKwh <= 20) return 'Lifeline 1 (0-20 kWh)';
    if (monthlyKwh <= 50) return 'Lifeline 2 (21-50 kWh)';
    if (monthlyKwh <= 100) return 'Low Consumption (51-100 kWh)';
    if (monthlyKwh <= 200) return 'Standard (101-200 kWh)';
    return 'Standard (200+ kWh)';
  }
}

/// Vehicle fuel efficiency data (km per liter, typical Filipino vehicles)
class VehicleFuelData {
  static const Map<String, double> kmPerLiter = {
    'Motorcycle': 40.0,
    'Sedan': 10.0,
    'SUV': 8.0,
    'Van/UV Express': 7.0,
    'Pickup Truck': 7.5,
    'Tricycle': 25.0,
  };
}
