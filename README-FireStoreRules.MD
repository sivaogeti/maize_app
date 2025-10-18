rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    function signedIn() { return request.auth != null; }

    match /farmers/{id} {
      allow read, create, update, delete: if signedIn();
    }
     match /input_issues/{id} {
      allow read, create, update, delete: if signedIn();
    }
    match /counters/{name} {
      allow read, write: if signedIn();
    }
     // NEW:
    match /field_observations/{id} {
      allow read, create, update, delete: if signedIn();
    }
    
    match /field_diagnostics/{doc} {
    allow read, update, delete: if request.auth != null
      && resource.data.createdBy == request.auth.uid;
    allow create: if request.auth != null
      && request.resource.data.createdBy == request.auth.uid;
  }
    
    // add inside match /databases/{db}/documents { ... }
    match /daily_logs/{id} {
      allow read, create, update, delete: if request.auth != null;
    }
    
    // NEW: Activity Schedule list (what the details screen reads)
    match /activity_schedule/{doc} {
      allow read, update, delete: if request.auth != null
         && resource.data.createdBy == request.auth.uid;
      allow create: if request.auth != null   
         && request.resource.data.createdBy == request.auth.uid;
    }
    
    // inside match /databases/{db}/documents {
    match /users/{uid} {
      // user can read self; super roles can read all
      allow read: if request.auth != null
                  && (uid == request.auth.uid
                      || get(/databases/$(db)/documents/users/$(request.auth.uid)).data.super == true);

      // create/update should be done by an admin/seed tool; keep off by default
      allow create, update, delete: if false;
    }
    
    match /{document=**} {
      allow read, write: if true;
    }

  }
}

