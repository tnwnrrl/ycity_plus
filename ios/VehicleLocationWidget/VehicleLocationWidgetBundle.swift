//
//  VehicleLocationWidgetBundle.swift
//  VehicleLocationWidget
//
//  Created by Jinhwan Jeon on 8/5/25.
//

import WidgetKit
import SwiftUI

@main
struct VehicleLocationWidgetBundle: WidgetBundle {
    var body: some Widget {
        VehicleLocationWidget()
        VehicleLocationWidgetControl()
    }
}
