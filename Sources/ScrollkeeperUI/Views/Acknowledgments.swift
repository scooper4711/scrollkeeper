import SwiftUI

/// Notices for the software Scrollkeeper includes. Their licenses require the notice to travel
/// with every copy of the app, so the text is part of the app itself.
enum Acknowledgments {
    static let zipFoundationName = "ZIPFoundation"
    static let zipFoundationPurpose = "Used to unpack zip archives."
    static let zipFoundationLicense = """
    MIT License

    Copyright (c) 2017-2025 Thomas Zoechling (https://www.peakstep.com)

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
    """
}

/// The acknowledgments, folded away until asked for.
struct AcknowledgmentsView: View {
    @State private var isExpanded = false

    var body: some View {
        Section {
            DisclosureGroup(Acknowledgments.zipFoundationName, isExpanded: $isExpanded) {
                Text(Acknowledgments.zipFoundationLicense)
                    .font(.caption)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("Acknowledgments")
        } footer: {
            Text(Acknowledgments.zipFoundationPurpose)
                .foregroundStyle(.secondary)
        }
    }
}
