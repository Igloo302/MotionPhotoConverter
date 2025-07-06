//
//  SupportedBrandsView.swift
//  MotionPhotoConverter
//
//  Created by Assistant on 2024/12/19.
//

import SwiftUI

struct SupportedBrandsView: View {
    let supportedBrands = MotionPhotoProcessorFactory.getAllSupportedBrands()
    
    // Pending support brands
    let pendingBrands = [
        (name: "Huawei", icon: "camera.circle", color: Color.red),
        (name: "Vivo", icon: "camera.viewfinder", color: Color.purple),
        (name: "OPPO", icon: "camera.metering.spot", color: Color.green)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Supported brands
            VStack(alignment: .leading, spacing: 8) {
                Text("✅ Supported Brands")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                ForEach(supportedBrands, id: \.self) { brand in
                    if brand == .android {
                        // Android devices show Pixel and Samsung separately
                        ForEach(getAndroidSubBrands(), id: \.name) { subBrand in
                            HStack {
                                Image(systemName: subBrand.icon)
                                    .foregroundColor(subBrand.color)
                                    .frame(width: 20)
                                
                                Text(subBrand.name)
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 2)
                        }
                    } else {
                        HStack {
                            Image(systemName: brandIcon(for: brand))
                                .foregroundColor(brandColor(for: brand))
                                .frame(width: 20)
                            
                            Text(getBrandDisplayName(for: brand))
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            
            Divider()
            
            // Pending support brands
            VStack(alignment: .leading, spacing: 8) {
                Text("🔄 Pending Support")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                ForEach(pendingBrands, id: \.name) { brand in
                    HStack {
                        Image(systemName: brand.icon)
                            .foregroundColor(brand.color)
                            .frame(width: 20)
                        
                        Text(brand.name)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Image(systemName: "clock.circle.fill")
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 2)
                }
                
                Text("Coming in future updates")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func brandIcon(for brand: MotionPhotoBrand) -> String {
        switch brand {
        case .xiaomi:
            return "camera.fill"
        case .android:
            return "camera.macro"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    private func brandColor(for brand: MotionPhotoBrand) -> Color {
        switch brand {
        case .xiaomi:
            return .orange
        case .android:
            return .blue
        case .unknown:
            return .gray
        }
    }
    
    private func getBrandDisplayName(for brand: MotionPhotoBrand) -> String {
        switch brand {
        case .xiaomi:
            return "Xiaomi"
        case .android:
            return "Android Devices"
        case .unknown:
            return "Unknown"
        }
    }
    
    private func getAndroidSubBrands() -> [(name: String, icon: String, color: Color)] {
        return [
            (name: "Pixel", icon: "camera.macro", color: Color.blue),
            (name: "Samsung", icon: "camera.aperture", color: Color.purple)
        ]
    }
    
    private func isFullySupported(_ brand: MotionPhotoBrand) -> Bool {
        // Xiaomi and Android (Pixel/Samsung) are fully supported
        return brand == .xiaomi || brand == .android
    }
}

#Preview {
    SupportedBrandsView()
        .padding()
}