//
//  ChatViewController.swift
//  Mogakco
//
//  Created by 오국원 on 2022/11/16.
//  Copyright © 2022 Mogakco. All rights reserved.
//

import UIKit

import RxCocoa
import RxKeyboard
import RxSwift
import SnapKit
import Then

final class ChatViewController: ViewController {
    
    // MARK: - Properties
    
    enum Constant {
        static let messageInputViewHeight = 100.0
        static let sidebarZPosition = 100.0
        static let collectionViewHeight = 60
    }
    
    private lazy var messageInputView = MessageInputView().then {
        $0.frame = CGRect(
            x: 0,
            y: 0,
            width: view.frame.width,
            height: 0
        )
    }
    
    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: UICollectionViewFlowLayout()
    ).then {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.sectionInset = UIEdgeInsets(
            top: 16,
            left: 0,
            bottom: 0,
            right: 0)
        layout.itemSize = CGSize(width: view.frame.width, height: 60)
        layout.minimumLineSpacing = 12.0
        $0.refreshControl = UIRefreshControl()
        $0.collectionViewLayout = layout
        $0.register(ChatCell.self, forCellWithReuseIdentifier: ChatCell.identifier)
        $0.alwaysBounceVertical = true
    }
    
    let studyInfoButton = UIButton().then {
        $0.setImage(UIImage(systemName: "line.horizontal.3"), for: .normal)
        $0.tintColor = .mogakcoColor.primaryDefault
    }
    
    lazy var sidebarView = ChatSidebarView().then {
        $0.frame = CGRect(
            x: view.frame.width,
            y: 0,
            width: view.frame.width,
            height: view.frame.height)
    }
    
    lazy var blackScreen = UIView(frame: self.view.bounds)
    private let viewModel: ChatViewModel
    
    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycles
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.isNavigationBarHidden = true
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func layout() {
        configure()
        layoutCollectionView()
        layoutSideBar()
        layoutBlackScreen()
        layoutMessageInputView()
    }
    
    private func layoutMessageInputView() {
        view.addSubview(messageInputView)
        
        messageInputView.snp.makeConstraints {
            $0.bottom.left.right.equalToSuperview()
            $0.top.equalTo(view.snp.bottom).inset(100)
        }
    }
    
    private func configure() {
        configureSideBar()
        configureBlackScreen()
        configureNavigationBar()
    }
    
    // MARK: - ViewController Methods
    
    override func bind() {
        let input = ChatViewModel.Input(
            backButtonDidTap: backButton.rx.tap.asObservable(),
            studyInfoButtonDidTap: studyInfoButton.rx.tap.asObservable(),
            selectedSidebar: sidebarView.tableView.rx.itemSelected.asObservable(),
            sendButtonDidTap: messageInputView.sendButton.rx.tap.asObservable(),
            inputViewText: messageInputView.messageInputTextView.rx.text.orEmpty.asObservable(),
            pagination: collectionView.refreshControl?.rx.controlEvent(.valueChanged).asObservable()
        )

        let output = viewModel.transform(input: input)
        
        Driver<[ChatSidebarMenu]>.just(ChatSidebarMenu.allCases)
            .drive(sidebarView.tableView.rx.items) { tableView, index, menu in
                guard let cell = tableView.dequeueReusableCell(
                    withIdentifier: ChatSidebarTableViewCell.identifier,
                    for: IndexPath(row: index, section: 0)) as? ChatSidebarTableViewCell else {
                    return UITableViewCell()
                }

                cell.menuLabel.text = menu.rawValue

                return cell
            }
            .disposed(by: disposeBag)
        
        viewModel.messages
            .asDriver(onErrorJustReturn: [])
            .drive(collectionView.rx.items) { collectionView, index, chat in
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: ChatCell.identifier,
                    for: IndexPath(row: index, section: 0)) as? ChatCell else {
                    return UICollectionViewCell()
                }
                cell.layoutChat(chat: chat)
                return cell
            }
            .disposed(by: disposeBag)
        
        output.showChatSidebarView
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] _ in
                guard let self = self else { return }
                self.showSidebarView()
            }
            .disposed(by: disposeBag)
        
        output.selectedSidebar
            .subscribe { [weak self] row in
                guard let self = self else { return }
                self.hideSidebarView()
            }
            .disposed(by: disposeBag)
        
        output.refreshFinished
            .subscribe(onNext: { [weak self] _ in
                self?.collectionView.refreshControl?.endRefreshing()
            })
            .disposed(by: disposeBag)
        
        output.sendMessage
            .withUnretained(self)
            .subscribe { _ in
                self.messageInputView.messageInputTextView.text = nil
                self.collectionView.scrollToItem(
                    at: IndexPath(
                        row: self.collectionView.numberOfItems(inSection: 0) - 1,
                        section: 0),
                    at: .bottom,
                    animated: true
                )
            }
            .disposed(by: disposeBag)

        RxKeyboard.instance.visibleHeight
            .skip(1)
            .drive(onNext: { [weak self] keyboardVisibleHeight in
                guard let self else { return }
                self.updateMessageInputLayout(height: keyboardVisibleHeight)
                self.updateCollectionViewLayout(height: keyboardVisibleHeight)
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Configures
    
    private func configureSideBar() {
        sidebarView.layer.zPosition = Constant.sidebarZPosition
        sidebarView.tableView.delegate = nil
        sidebarView.tableView.dataSource = nil
        self.view.isUserInteractionEnabled = true
    }
    
    private func configureBlackScreen() {
        blackScreen.backgroundColor = .black.withAlphaComponent(0.5)
        blackScreen.isHidden = true
        let tapGestRecognizer = UITapGestureRecognizer(target: self, action: #selector(blackScreenTapAction(sender:)))
        blackScreen.addGestureRecognizer(tapGestRecognizer)
    }
    
    private func configureNavigationBar() {
        navigationItem.title = "채팅"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: studyInfoButton)
    }
    
    // MARK: - Layouts
    
    private func layoutCollectionView() {
        view.addSubview(collectionView)
        collectionView.rx.setDelegate(self).disposed(by: disposeBag)
        collectionView.snp.makeConstraints {
            $0.top.left.right.equalToSuperview()
            $0.bottom.equalToSuperview().inset(Constant.messageInputViewHeight)
        }
    }
    
    private func layoutSideBar() {
        self.navigationController?.view.addSubview(sidebarView)
    }
    
    private func layoutBlackScreen() {
        view.addSubview(blackScreen)
        
        blackScreen.layer.zPosition = Constant.sidebarZPosition
    }
    
    private func layoutMessageInputView() {
        view.addSubview(messageInputView)
        
        messageInputView.snp.makeConstraints {
            $0.bottom.left.right.equalToSuperview()
            $0.top.equalTo(view.snp.bottom).inset(Constant.messageInputViewHeight)
        }
    }
    
    private func updateMessageInputLayout(height: CGFloat) {
        if height == 0 {
            self.messageInputView.snp.remakeConstraints {
                $0.bottom.left.right.equalToSuperview()
                $0.top.equalTo(self.view.snp.bottom).inset(Constant.messageInputViewHeight)
            }
        } else {
            UIView.animate(withDuration: 0.5) { [weak self] in
                guard let self else { return }
                self.messageInputView.snp.remakeConstraints {
                    $0.left.right.equalTo(self.view.safeAreaLayoutGuide)
                    $0.bottom.equalToSuperview().inset(height)
                }
            }
        }
    }
    
    private func updateCollectionViewLayout(height: CGFloat) {
        if height == 0 {
            self.collectionView.snp.remakeConstraints {
                $0.top.left.right.equalToSuperview()
                $0.bottom.equalToSuperview().inset(Constant.messageInputViewHeight)
            }
        } else {
            UIView.animate(withDuration: 0.5) { [weak self] in
                guard let self else { return }
                self.collectionView.snp.remakeConstraints {
                    $0.top.left.right.equalToSuperview()
                    $0.bottom.equalTo(self.messageInputView.snp.top)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func showSidebarView() {
        navigationItem.leftBarButtonItem?.isHidden = true

        blackScreen.isHidden = false
        UIView.animate(
            withDuration: 0.3,
            animations: {
                self.sidebarView.frame = CGRect(
                    x: self.view.frame.width * (2 / 3),
                    y: 0,
                    width: self.view.frame.width * (1 / 3),
                    height: self.sidebarView.frame.height)
                
                self.blackScreen.frame = CGRect(
                    x: 0,
                    y: 0,
                    width: self.view.frame.width * (2 / 3),
                    height: self.view.bounds.height)
            }
        )
    }
    
    private func hideSidebarView() {
        blackScreen.isHidden = true
        blackScreen.frame = self.view.bounds
        
        UIView.animate(withDuration: 0.3) {
            self.sidebarView.frame = CGRect(
                x: self.view.frame.width,
                y: 0,
                width: self.sidebarView.frame.width,
                height: self.sidebarView.frame.height
            )
        }
    }
    
    @objc func blackScreenTapAction(sender: UITapGestureRecognizer) {
        blackScreen.isHidden = true
        blackScreen.frame = view.bounds
        
        UIView.animate(withDuration: 0.3) {
            self.sidebarView.frame = CGRect(
                x: self.view.frame.width,
                y: 0,
                width: self.view.frame.width,
                height: self.sidebarView.frame.height
            )
        }
    }
}
