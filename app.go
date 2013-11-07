package heroku

import (
	"time"
)

// An app represents the program that you would like to deploy and run on
// Heroku.
type App struct {
	// when app was archived
	ArchivedAt time.Time `json:"archived_at"`

	// description from buildpack of app
	BuildpackProvidedDescription string `json:"buildpack_provided_description"`

	// when app was created
	CreatedAt time.Time `json:"created_at"`

	// git repo URL of app
	GitUrl string `json:"git_url"`

	// unique identifier of app
	Id string `json:"id"`

	// maintenance status of app
	Maintenance bool `json:"maintenance"`

	// unique name of app
	Name string `json:"name"`

	// identity of app region
	Region Region `json:"region"`

	// when app was released
	ReleasedAt time.Time `json:"released_at"`

	// git repo size in bytes of app
	RepoSize int `json:"repo_size"`

	// slug size in bytes of app
	SlugSize int `json:"slug_size"`

	// identity of app stack
	Stack Stack `json:"stack"`

	// when app was updated
	UpdatedAt time.Time `json:"updated_at"`

	// web URL of app
	WebUrl string `json:"web_url"`
}

// Create a new app.
//
// name, region, and stack are optional.
func (c *Client) AppCreate(name, region, stack string) (*App, error) {
	var body struct {
		Name   string `json:"name,omitempty"`
		Region string `json:"region,omitempty"`
		Stack  string `json:"stack,omitempty"`
	}
	body.Name = name
	body.Region = region
	body.Stack = stack
	var app App
	if err := c.Post(&app, "/apps", body); err != nil {
		return nil, err
	}
	return &app, nil
}

// Info for existing app.
//
// nameOrId is the unique name of app or unique identifier of app
func (c *Client) AppInfo(nameOrId string) (*App, error) {
	var app App
	if err := c.Get(&app, "/apps/" + nameOrId); err != nil {
		return nil, err
	}
	return &app, nil
}

// Delete an existing app.
//
// nameOrId is the unique name of app or unique identifier of app
func (c *Client) AppDelete(nameOrId string) error {
	return c.Delete("/apps/" + nameOrId)
}
