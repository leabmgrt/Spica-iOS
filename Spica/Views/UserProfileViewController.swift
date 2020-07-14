//
//  UserProfileViewController.swift
//  Spica
//
//  Created by Adrian Baumgart on 30.06.20.
//

import Combine
import JGProgressHUD
import SPAlert
import SwiftKeychainWrapper
import UIKit

class UserProfileViewController: UIViewController {
    var user: User!
    var tableView: UITableView!
    var userPosts = [Post]() {
        didSet {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    var signedInUsername: String!

    var refreshControl = UIRefreshControl()

    var loadingHud: JGProgressHUD!

    private var subscriptions = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        navigationItem.title = "\(user.displayName)"
        signedInUsername = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.username")
        navigationController?.navigationBar.prefersLargeTitles = false

        if signedInUsername == user.username {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: nil)
        }

        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView?.delegate = self
        tableView?.dataSource = self
        tableView.register(PostCellView.self, forCellReuseIdentifier: "postCell")
        tableView.register(UserHeaderCellView.self, forCellReuseIdentifier: "userHeaderCell")

        view.addSubview(tableView)

        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(loadUser), for: .valueChanged)
        tableView.addSubview(refreshControl)

        loadingHud = JGProgressHUD(style: .dark)
        loadingHud.textLabel.text = "Loading"
        loadingHud.interactionType = .blockNoTouches
    }

    override func viewWillAppear(_: Bool) {
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    override func viewDidAppear(_: Bool) {
        loadUser()
    }

    @objc func loadUser() {
        if user == nil || userPosts.isEmpty {
            loadingHud.show(in: view)
        }
        DispatchQueue.main.async { [self] in

            AllesAPI.default.loadUser(username: self.user.username)
                .receive(on: RunLoop.current)
                .sink {
                    switch $0 {
                    case let .failure(err):
                        DispatchQueue.main.async {
                            EZAlertController.alert("Error", message: err.message, buttons: ["Ok"]) { _, _ in
                                if self.refreshControl.isRefreshing {
                                    self.refreshControl.endRefreshing()
                                }
                                self.loadingHud.dismiss()
                                if err.action != nil, err.actionParameter != nil {
                                    if err.action == AllesAPIErrorAction.navigate {
                                        if err.actionParameter == "login" {
                                            let mySceneDelegate = self.view.window!.windowScene!.delegate as! SceneDelegate
                                            mySceneDelegate.window?.rootViewController = UINavigationController(rootViewController: LoginViewController())
                                            mySceneDelegate.window?.makeKeyAndVisible()
                                        }
                                    }
                                }
                            }
                        }
                    default: break
                    }
                } receiveValue: { [unowned self] in
                    self.user = $0
                    self.navigationItem.title = "\(self.user.displayName)"
                    self.loadPfp()
                    self.loadPosts()
                }
                .store(in: &subscriptions)
        }
    }

    func loadPosts() {
        AllesAPI.default.loadUserPosts(user: user)
            .receive(on: RunLoop.main)
            .sink {
                switch $0 {
                case let .failure(err):
                    DispatchQueue.main.async {
                        EZAlertController.alert("Error", message: err.message, buttons: ["Ok"]) { _, _ in
                            if self.refreshControl.isRefreshing {
                                self.refreshControl.endRefreshing()
                            }
                            self.loadingHud.dismiss()
                            if err.action != nil, err.actionParameter != nil {
                                if err.action == AllesAPIErrorAction.navigate {
                                    if err.actionParameter == "login" {
                                        let mySceneDelegate = self.view.window!.windowScene!.delegate as! SceneDelegate
                                        mySceneDelegate.window?.rootViewController = UINavigationController(rootViewController: LoginViewController())
                                        mySceneDelegate.window?.makeKeyAndVisible()
                                    }
                                }
                            }
                        }
                    }
                default: break
                }
            } receiveValue: { [unowned self] in

                self.userPosts = $0
                if self.refreshControl.isRefreshing {
                    self.refreshControl.endRefreshing()
                }
                self.loadingHud.dismiss()
                self.loadImages()
            }
            .store(in: &subscriptions)
    }

    func loadPfp() {
        DispatchQueue.global(qos: .utility).async {
            let dispatchGroup = DispatchGroup()

            dispatchGroup.enter()

            self.user.image = ImageLoader.loadImageFromInternet(url: self.user.imageURL)

            DispatchQueue.main.async {
                self.tableView.beginUpdates()
                self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
                self.tableView.endUpdates()
            }

            dispatchGroup.leave()
        }
    }

    func loadImages() {
        DispatchQueue.global(qos: .utility).async {
            let dispatchGroup = DispatchGroup()

            for (index, post) in self.userPosts.enumerated() {
                if index > self.userPosts.count - 1 {
                } else {
                    dispatchGroup.enter()

                    DispatchQueue.main.async {
                        self.userPosts[index].author.image = ImageLoader.loadImageFromInternet(url: post.author.imageURL)
                    }

                    if index > 10 {
                        if index % 5 == 0 {}
                    }

                    if index % 5 == 0 {
                        DispatchQueue.main.async {
                            self.tableView.reloadData()
                        }
                    }

                    if let url = post.imageURL {
                        self.userPosts[index].image = ImageLoader.loadImageFromInternet(url: url)
                    } else {
                        self.userPosts[index].image = UIImage()
                    }

                    if index % 5 == 0 {
                        DispatchQueue.main.async {
                            self.tableView.reloadData()
                        }
                    }

                    dispatchGroup.leave()
                }
            }
        }
    }

    @objc func openUserProfile(_ sender: UITapGestureRecognizer) {
        let userByTag = userPosts[sender.view!.tag].author
        let vc = UserProfileViewController()
        vc.user = userByTag
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func upvotePost(_ sender: UIButton) {
        let selectedPost = userPosts[sender.tag]
        var selectedVoteStatus = 0
        if selectedPost.voteStatus == 1 {
            selectedVoteStatus = 0
        } else {
            selectedVoteStatus = 1
        }

        AllesAPI.default.votePost(post: selectedPost, value: selectedVoteStatus)
            .receive(on: RunLoop.main)
            .sink {
                switch $0 {
                case let .failure(err):
                    EZAlertController.alert("Error", message: err.message, buttons: ["Ok"]) { _, _ in
                        if err.action != nil, err.actionParameter != nil {
                            if err.action == AllesAPIErrorAction.navigate {
                                if err.actionParameter == "login" {
                                    let mySceneDelegate = self.view.window!.windowScene!.delegate as! SceneDelegate
                                    mySceneDelegate.window?.rootViewController = UINavigationController(rootViewController: LoginViewController())
                                    mySceneDelegate.window?.makeKeyAndVisible()
                                }
                            }
                        }
                    }
                default: break
                }
            } receiveValue: { [self] _ in
                if self.userPosts[sender.tag].voteStatus == -1 {
                    self.userPosts[sender.tag].score += 2
                } else if selectedVoteStatus == 0 {
                    self.userPosts[sender.tag].score -= 1
                } else {
                    self.userPosts[sender.tag].score += 1
                }
                self.userPosts[sender.tag].voteStatus = selectedVoteStatus

                self.tableView.beginUpdates()
                self.tableView.reloadRows(at: [IndexPath(row: sender.tag, section: 1)], with: .automatic)
                self.tableView.endUpdates()
                self.loadPosts()
            }.store(in: &subscriptions)
    }

    @objc func downvotePost(_ sender: UIButton) {
        let selectedPost = userPosts[sender.tag]
        var selectedVoteStatus = 0
        if selectedPost.voteStatus == -1 {
            selectedVoteStatus = 0
        } else {
            selectedVoteStatus = -1
        }

        AllesAPI.default.votePost(post: selectedPost, value: selectedVoteStatus)
            .receive(on: RunLoop.main)
            .sink {
                switch $0 {
                case let .failure(err):
                    EZAlertController.alert("Error", message: err.message, buttons: ["Ok"]) { _, _ in
                        if err.action != nil, err.actionParameter != nil {
                            if err.action == AllesAPIErrorAction.navigate {
                                if err.actionParameter == "login" {
                                    let mySceneDelegate = self.view.window!.windowScene!.delegate as! SceneDelegate
                                    mySceneDelegate.window?.rootViewController = UINavigationController(rootViewController: LoginViewController())
                                    mySceneDelegate.window?.makeKeyAndVisible()
                                }
                            }
                        }
                    }
                default: break
                }
            } receiveValue: { [self] _ in
                if self.userPosts[sender.tag].voteStatus == 1 {
                    self.userPosts[sender.tag].score -= 2
                } else if selectedVoteStatus == 0 {
                    self.userPosts[sender.tag].score += 1
                } else {
                    self.userPosts[sender.tag].score -= 1
                }
                self.userPosts[sender.tag].voteStatus = selectedVoteStatus

                self.tableView.beginUpdates()
                self.tableView.reloadRows(at: [IndexPath(row: sender.tag, section: 1)], with: .automatic)
                self.tableView.endUpdates()
                self.loadPosts()
            }.store(in: &subscriptions)
    }

    @objc func followUnfollowUser() {
        AllesAPI.default.performFollowAction(username: user.username, action: user.isFollowing ? .unfollow : .follow)
            .receive(on: RunLoop.main)
            .sink {
                switch $0 {
                case let .failure(err):
                    EZAlertController.alert("Error", message: err.message, buttons: ["Ok"]) { _, _ in
                        if err.action != nil, err.actionParameter != nil {
                            if err.action == AllesAPIErrorAction.navigate {
                                if err.actionParameter == "login" {
                                    let mySceneDelegate = self.view.window!.windowScene!.delegate as! SceneDelegate
                                    mySceneDelegate.window?.rootViewController = UINavigationController(rootViewController: LoginViewController())
                                    mySceneDelegate.window?.makeKeyAndVisible()
                                }
                            }
                        }
                    }
                default: break
                }
            } receiveValue: { [unowned self] in
                self.user.isFollowing = $0 == .follow ? true : false
                if $0 == .follow {
                    self.user.followers += 1
                } else {
                    self.user.followers -= 1
                }
                self.tableView.beginUpdates()
                self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
                self.tableView.endUpdates()
            }.store(in: &subscriptions)
    }
}

extension UserProfileViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        2
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : userPosts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "userHeaderCell", for: indexPath) as! UserHeaderCellView
            cell.selectionStyle = .none
            cell.user = user
            cell.followButton.addTarget(self, action: #selector(followUnfollowUser), for: .touchUpInside)
            return cell
        } else {
            let post = userPosts[indexPath.row]

            let cell = tableView.dequeueReusableCell(withIdentifier: "postCell", for: indexPath) as! PostCellView

            cell.delegate = self
            cell.indexPath = indexPath
            cell.post = post

            let tap = UITapGestureRecognizer(target: self, action: #selector(openUserProfile(_:)))
            cell.pfpImageView.tag = indexPath.row
            cell.pfpImageView.isUserInteractionEnabled = true
            cell.pfpImageView.addGestureRecognizer(tap)

            cell.upvoteButton.tag = indexPath.row
            cell.upvoteButton.addTarget(self, action: #selector(upvotePost(_:)), for: .touchUpInside)
            cell.downvoteButton.tag = indexPath.row
            cell.downvoteButton.addTarget(self, action: #selector(downvotePost(_:)), for: .touchUpInside)

            return cell
        }
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            let detailVC = PostDetailViewController()
            detailVC.selectedPostID = userPosts[indexPath.row].id
            detailVC.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(detailVC, animated: true)
        }
    }
}

extension UserProfileViewController: PostCreateDelegate {
    func didSendPost(sentPost: SentPost) {
        let detailVC = PostDetailViewController()
        detailVC.selectedPostID = sentPost.id
        detailVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

extension UserProfileViewController: PostCellViewDelegate {
    func repost(id: String, username: String) {
        let vc = PostCreateViewController()
        vc.type = .post
        vc.delegate = self
        vc.preText = "@\(username)\n\n\n\n%\(id)"
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    func replyToPost(id: String) {
        let vc = PostCreateViewController()
        vc.type = .reply
        vc.delegate = self
        vc.parentID = id
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    func copyPostID(id: String) {
        let pasteboard = UIPasteboard.general
        pasteboard.string = id
        SPAlert.present(title: "Copied", preset: .done)
    }

    func deletePost(id: String) {
        EZAlertController.alert("Delete post", message: "Are you sure you want to delete this post?", buttons: ["Cancel", "Delete"], buttonsPreferredStyle: [.cancel, .destructive]) { [self] _, int in
            if int == 1 {
                AllesAPI.default.deletePost(id: id)
                    .receive(on: RunLoop.main)
                    .sink {
                        switch $0 {
                        case let .failure(err):
                            EZAlertController.alert("Error", message: err.message, buttons: ["Ok"]) { _, _ in
                                if self.refreshControl.isRefreshing {
                                    self.refreshControl.endRefreshing()
                                }
                                self.loadingHud.dismiss()
                                if err.action != nil, err.actionParameter != nil {
                                    if err.action == AllesAPIErrorAction.navigate {
                                        if err.actionParameter == "login" {
                                            let mySceneDelegate = self.view.window!.windowScene!.delegate as! SceneDelegate
                                            mySceneDelegate.window?.rootViewController = UINavigationController(rootViewController: LoginViewController())
                                            mySceneDelegate.window?.makeKeyAndVisible()
                                        }
                                    }
                                }
                            }
                        default: break
                        }
                    } receiveValue: { _ in
                        self.loadPosts()
                    }.store(in: &subscriptions)
            }
        }
    }

    func selectedPost(post: String, indexPath _: IndexPath) {
        let detailVC = PostDetailViewController()
        detailVC.selectedPostID = post
        detailVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(detailVC, animated: true)
    }

    func selectedURL(url: String, indexPath _: IndexPath) {
        if UIApplication.shared.canOpenURL(URL(string: url)!) {
            UIApplication.shared.open(URL(string: url)!)
        }
    }

    func selectedUser(username: String, indexPath _: IndexPath) {
        let user = User(id: username, username: username, displayName: username, imageURL: URL(string: "https://avatar.alles.cx/u/\(username)")!, isPlus: false, rubies: 0, followers: 0, image: ImageLoader.loadImageFromInternet(url: URL(string: "https://avatar.alles.cx/u/\(username)")!), isFollowing: false, followsMe: false, about: "", isOnline: false)
        let vc = UserProfileViewController()
        vc.user = user
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }
}
