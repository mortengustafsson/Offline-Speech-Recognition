//
//  ViewController.swift
//  Offline Speech Recognition
//
//  Created by Morten Gustafsson on 23/09/2020.
//  Copyright © 2020 mortengustafsson. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    private let recordButton = UIButton(type: .custom)
    private let label = UILabel()
    private let offlineSpeechRecognizer = OfflineSpeechRecognizer.shared

    private var isRecording: Bool = false {
        didSet {
            self.recordButton.backgroundColor = isRecording ? #colorLiteral(red: 0.8078431487, green: 0.02745098062, blue: 0.3333333433, alpha: 1) : #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
            self.recordButton.setTitle(isRecording ? "Stop Recording" : "Start Recording", for: .normal)
        }
    }

    private let consoleView = UITextView()
    private let contentView = UIView()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Will use "en-US" because it supports on-device recognition.
        offlineSpeechRecognizer.prepareListening(forLanguage: "en", andCountry: "US", completion: { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    self.log(message: "PrepareListening: Success.")
                case .error(let error):
                    self.log(message: "Error: " + String(describing: error))
                    self.recordButton.isHidden = true
                }
            }
        })
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        consoleView.backgroundColor = UIColor.ConsoleViewColor()
        consoleView.isEditable = false
        consoleView.layer.cornerRadius = 10
        consoleView.textContainerInset = UIEdgeInsets(top: 5, left: 5, bottom: 0, right: 5)
        consoleView.textColor = UIColor.ConsoleViewTextColor()

        view.addSubview(label)
        view.addSubview(recordButton)
        view.addSubview(consoleView)
        view.addSubview(contentView)

        recordButton.setTitle("Record", for: .normal)
        recordButton.addTarget(self, action: #selector(didTapRecord), for: .touchUpInside)
        recordButton.layer.cornerRadius = 5
        recordButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        isRecording = false

        offlineSpeechRecognizer.delegate = self

        setupConstriants()
    }

    private func setupConstriants() {
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        consoleView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            consoleView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            consoleView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            consoleView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            consoleView.heightAnchor.constraint(equalToConstant: 200),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.topAnchor.constraint(equalTo: consoleView.bottomAnchor, constant: 20),
            contentView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            contentView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 10),
            contentView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -10),
            contentView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    @objc func didTapRecord() {
        isRecording ? offlineSpeechRecognizer.stopListening() : offlineSpeechRecognizer.startListening()
    }

    internal func log(message: String) {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.consoleView.insertText(formatter.string(from: date) + ": " + message + "\n")
            let range = NSMakeRange(self.consoleView.text.count - 1, 0)
            self.consoleView.scrollRangeToVisible(range)
        }
    }
}

extension ViewController: OfflineSpeechRecognizerDelegate {

    public func error(_ offlineSpeechRecognizer: OfflineSpeechRecognizer) {
        recordButton.isHidden = true
        log(message: "Something went wrong! Offline Speech Reconition is not possible.")
    }

    public func result(_ offlineSpeechRecognizer: OfflineSpeechRecognizer, message: String) {
        label.text = message
        log(message: message)
    }

    public func log(_ offlineSpeechRecognizer: OfflineSpeechRecognizer, message: String) {
        log(message: message)
    }

    public func didStopListening(_ offlineSpeechRecognizer: OfflineSpeechRecognizer) {
        isRecording = false
        log(message: "Did Stop Listening")
    }

    public func didStartListening(_ offlineSpeechRecognizer: OfflineSpeechRecognizer) {
        isRecording = true
        log(message: "Did Start Listening")

    }
}
