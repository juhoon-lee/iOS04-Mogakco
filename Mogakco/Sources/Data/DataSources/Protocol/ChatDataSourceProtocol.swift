//
//  ChatDataSourceProtocol.swift
//  Mogakco
//
//  Created by 김범수 on 2022/11/21.
//  Copyright © 2022 Mogakco. All rights reserved.
//

import RxSwift

protocol ChatDataSourceProtocol {
    func fetch(chatRoomID: String) -> Observable<[ChatResponseDTO]>
    func send(chat: Chat, to chatRoomID: String) -> Observable<Void> // Void? Error?
}
