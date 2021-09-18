{
  this._firstName = firstName;
  this._lastName = lastName;

  this.log = function() {
      console.log('I am ', this._firstName, this._lastName);
  }

  Object.defineProperty(this, 'profession', {
      set: function(val) {
          this._profession = val;
      },
      get: function() {
          console.log(this._firstName, this._lastName, 'is a', this._profession);
      }
  })
}