//
//  SupportedBrandsView.swift
//  MotionPhotoConverter
//
//  Created by Assistant on 2024/12/19.
//

import SwiftUI

struct SupportedBrandsView: View {
    let supportedBrands = MotionPhotoProcessorFactory.getAllSupportedBrands()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("支持的动态照片格式")
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(supportedBrands, id: \.self) { brand in
                HStack {
                    Image(systemName: brandIcon(for: brand))
                        .foregroundColor(brandColor(for: brand))
                        .frame(width: 20)
                    
                    Text(brand.displayName)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    if isFullySupported(brand) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "clock.circle.fill")
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 2)
            }
            
            // 所有支持的品牌均已完全实现
            Text("✅ 所有格式均已完全支持")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func brandIcon(for brand: MotionPhotoBrand) -> String {
        switch brand {
        case .xiaomi:
            return "camera.fill"
        case .pixel:
            return "camera.macro"
        case .samsung:
            return "camera.aperture"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    private func brandColor(for brand: MotionPhotoBrand) -> Color {
        switch brand {
        case .xiaomi:
            return .orange
        case .pixel:
            return .blue
        case .samsung:
            return .purple
        case .unknown:
            return .gray
        }
    }
    
    private func isFullySupported(_ brand: MotionPhotoBrand) -> Bool {
        // 小米、Pixel、三星均已完全支持
        return brand == .xiaomi || brand == .pixel || brand == .samsung
    }
}

#Preview {
    SupportedBrandsView()
        .padding()
}