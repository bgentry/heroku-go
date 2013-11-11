package heroku

import (
	"time"
)

// A region represents a geographic location in which your application may run.
type Account struct {
	// whether to allow third party web activity tracking
	AllowTracking bool `json:"allow_tracking"`

	// whether to utilize beta Heroku features
	Beta bool `json:"beta"`

	// when account was created
	CreatedAt time.Time `json:"created_at"`

	// unique email address of account
	Email string `json:"email"`

	// unique identifier of an account
	Id string `json:"id"`

	// when account last authorized with Heroku
	LastLogin time.Time `json:"updated_at"`

	// when account was updated
	UpdatedAt time.Time `json:"updated_at"`

	// whether account has been verified with billing information
	Verified bool `json:"verified"`
}
