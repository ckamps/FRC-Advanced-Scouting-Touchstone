////////////////////////////////////////////////////////////////////////////
//
// Copyright 2017 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import UIKit


@objc public protocol LoginCredentialsValidationProtocol {
    /** Provides basic sanitation check to ensure URL is valid */
    func isValidServerURL(_ serverURL: String?) -> Bool

    /** Provides basic check to port number is a correct value. */
    func isValidPortNumber(_ portNumber: Int) -> Bool

    /** Provides basic check to ensure a valid username value was set */
    func isValidUsername(_ username: String?) -> Bool

    /** Provides a basic check to ensure a valid password value was set */
    func isValidPassword(_ password: String?) -> Bool

    /** Provides a basic check to make sure `password` matches with `confirmPassword` */
    func isPassword(_ password: String?, matching confirmPassword: String?) -> Bool
    
    func isValidEmail(_ email: String?) -> Bool
    
    func isEmail(_ email: String?, matching confirmEmail: String?) -> Bool
}

@objc(RLMLoginCredentialsValidation)
public class LoginCredentialsValidation: NSObject, LoginCredentialsValidationProtocol {
    
    public func isValidServerURL(_ serverURL: String?) -> Bool {
        guard let serverURL = serverURL else { return false }
        return !serverURL.isEmpty
    }

    public func isValidPortNumber(_ portNumber: Int) -> Bool {
        return (0...65535 ~= portNumber)
    }

    public func isValidUsername(_ username: String?) -> Bool {
        guard let username = username else { return false }
        
        guard let teamNumber = Int(username) else {
            return false
        }
        
        return teamNumber > 0 && teamNumber < 9999
    }

    public func isValidPassword(_ password: String?) -> Bool {
        guard let password = password else { return false }
        
        return password.count >= 6
    }

    public func isPassword(_ password: String?, matching confirmPassword: String?) -> Bool {
        guard let password = password, let confirmPassword = confirmPassword else { return false }

        return password == confirmPassword
    }
    
    public func isValidEmail(_ email: String?) -> Bool {
        guard let email = email else {return false}
        
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        
        let emailTest = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: email)
    }
    
    public func isEmail(_ email: String?, matching confirmEmail: String?) -> Bool {
        return email == confirmEmail
    }
}
