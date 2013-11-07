package heroku

import (
	"time"
)

// Stacks are the different application execution environments available in the
// Heroku platform.
type Stack struct {
	// when stack was introduced
	CreatedAt time.Time `json:"created_at"`

	// unique identifier of stack
	Id string `json:"id"`

	// unique name of stack
	Name string `json:"name"`

	// availability of this stack: beta, deprecated or public
	State string `json:"state"`

	// when stack was last modified
	UpdatedAt time.Time `json:"updated_at"`
}
