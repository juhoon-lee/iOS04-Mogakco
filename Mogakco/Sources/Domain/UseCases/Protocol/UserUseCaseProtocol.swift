//
//  UserUseCaseProtocol.swift
//  Mogakco
//
//  Created by 김범수 on 2022/11/21.
//  Copyright © 2022 Mogakco. All rights reserved.
//

import RxSwift

protocol UserUseCaseProtocol {
    func user(id: String) -> Observable<User>
}
