//
//  UserHeaderView.swift
//  Spica
//
//  Created by Adrian Baumgart on 01.08.20.
//

import SwiftUI

struct UserHeaderView: View {
    @ObservedObject var controller: UserHeaderViewController

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Group {
                    Image(uiImage: controller.user.image!)
                        .resizable()
                        .clipped()
                        .frame(width: 120, height: 120, alignment: .center)
                        .clipShape(Circle())
                        .shadow(radius: 10)
                        .overlay(Circle()

                            .trim(from: 0, to: controller.grow ? 1 : 0)
                            .stroke(controller.user.isOnline ? Color.green : Color.gray, lineWidth: 4)
                            .rotationEffect(.degrees(90), anchor: .center)
                            .animation(.easeInOut(duration: 1))
                            .shadow(radius: 10)
                        )
                    /* .onAppear {
                     	self.grow.toggle()
                     } */
                }
                Spacer()
            }
            Group {
                Text("\(controller.user.displayName)\(controller.user.isPlus ? String("⁺") : String(""))").font(.title).bold()
                Text("@\(controller.user.username)").foregroundColor(.secondary)
                if controller.user.followsMe && !controller.isLoggedInUser {
                    Text(SLocale(.FOLLOWS_YOU)).foregroundColor(.init(UIColor.tertiaryLabel))
                }
                Text(controller.user.about).padding([.top, .bottom])
                HStack {
                    Group {
                        Text("\(controller.user.followers) ").bold() + Text(countString(number: controller.user.followers, singleText: SLocale(.FOLLOWER_SINGULAR), multiText: SLocale(.FOLLOWER_PLURAL), includeNumber: false))
                    }.padding(.trailing).fixedSize(horizontal: true, vertical: true)

                    Group {
                        Text("\(controller.user.rubies) ").bold() + Text(countString(number: controller.user.rubies, singleText: SLocale(.RUBY_SINGULAR), multiText: SLocale(.RUBY_PLURAL), includeNumber: false))
                    }.fixedSize(horizontal: true, vertical: true)
                }

                if !controller.isLoggedInUser {
                    Button(action: {
                        controller.followUnfollowUser()
                    }, label: {
                        if controller.user.isFollowing {
                            Group {
                                Text(SLocale(.FOLLOWING_ACTION)).padding().foregroundColor(.white)
                            }.background(Color.blue).shadow(radius: 10).cornerRadius(12.0)
                                .padding(.top, 16)
                        } else {
                            Group {
                                Text(SLocale(.FOLLOW_ACTION)).padding().foregroundColor(.blue)
                            }.background(Color("UserBackground")).shadow(radius: 10).cornerRadius(12.0)
                                .padding(.top, 16)
                        }
					})
                }

            }.padding(.leading)

        }.padding(16)
            .onAppear {
                controller.getLoggedInUser()
            }
    }
}

struct UserHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        UserHeaderView(controller: UserHeaderViewController())
    }
}
