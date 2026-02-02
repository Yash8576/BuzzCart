# Contributing to Like2Share (BuzzCart)

Thank you for considering contributing! This document provides guidelines for contributing to the project.

## Table of Contents
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Branch Strategy](#branch-strategy)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Code Standards](#code-standards)
- [Testing Requirements](#testing-requirements)

---

## Getting Started

### Prerequisites
- Python 3.11+
- Node.js 20+
- Flutter 3.24+ (for mobile app)
- MongoDB (local or Atlas)
- Git

### First-Time Setup

```bash
# 1. Fork the repository on GitHub

# 2. Clone your fork
git clone https://github.com/YOUR-USERNAME/Like2Share.git
cd Like2Share

# 3. Add upstream remote
git remote add upstream https://github.com/original-org/Like2Share.git

# 4. Create .env files from examples
cp webapp/backend/.env.example webapp/backend/.env
cp webapp/frontend/.env.example webapp/frontend/.env

# 5. Install dependencies (see DEPLOYMENT.md)
```

---

## Development Workflow

### Trunk-Based Development

We use **trunk-based development** with short-lived feature branches:

1. `main` branch is always releasable (production-ready)
2. Create feature branches from `main`
3. Merge back to `main` via Pull Requests
4. Deploy staging automatically from `main`
5. Deploy production from version tags (`v1.0.0`)

### Syncing with Upstream

```bash
# Update your local main
git checkout main
git fetch upstream
git merge upstream/main
git push origin main
```

---

## Branch Strategy

### Branch Naming Convention

```bash
# Features
feature/TICKET-123-add-video-upload
feature/improve-cart-performance

# Bug Fixes
fix/TICKET-456-login-error
fix/cart-quantity-bug

# Hotfixes (for production)
hotfix/v1.2.1-security-patch

# Documentation
docs/update-deployment-guide

# Refactoring
refactor/clean-up-api-service
```

### Creating a Feature Branch

```bash
# Always branch from main
git checkout main
git pull origin main
git checkout -b feature/your-feature-name
```

---

## Commit Guidelines

### Commit Message Format

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

#### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style (formatting, no logic change)
- `refactor`: Code refactoring
- `perf`: Performance improvement
- `test`: Adding/updating tests
- `chore`: Build/config changes

#### Examples

```bash
# Good commits
feat(cart): add quantity increment buttons
fix(auth): resolve JWT token expiration bug
docs(readme): update installation instructions
refactor(api): extract user service into separate module

# Bad commits
update stuff
fix bug
WIP
changes
```

### Making Commits

```bash
# Stage changes
git add .

# Commit with message
git commit -m "feat(videos): add video upload functionality"

# Push to your fork
git push origin feature/your-feature-name
```

---

## Pull Request Process

### Before Creating PR

- [ ] Code follows style guidelines
- [ ] All tests pass locally
- [ ] Linting passes (`flake8`, `eslint`, `flutter analyze`)
- [ ] No console.log/print statements (use proper logging)
- [ ] Updated documentation if needed
- [ ] Added tests for new features
- [ ] No merge conflicts with `main`

### Creating Pull Request

1. **Push your branch** to your fork
   ```bash
   git push origin feature/your-feature
   ```

2. **Open PR on GitHub**
   - Go to original repository
   - Click "New Pull Request"
   - Select your fork and branch
   - Fill in PR template

3. **PR Title Format**
   ```
   [Type] Brief description (#TICKET)
   
   Examples:
   [Feature] Add video upload to shop page (#123)
   [Fix] Resolve cart total calculation bug (#456)
   ```

4. **PR Description Template**
   ```markdown
   ## Description
   Brief description of changes

   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Breaking change
   - [ ] Documentation update

   ## How Has This Been Tested?
   - [ ] Unit tests
   - [ ] Integration tests
   - [ ] Manual testing

   ## Screenshots (if applicable)
   Add screenshots here

   ## Checklist
   - [ ] Code follows style guidelines
   - [ ] Self-review completed
   - [ ] Tests added/updated
   - [ ] Documentation updated
   - [ ] No breaking changes (or documented)
   ```

### Review Process

1. **Automated Checks** run (CI)
   - Backend: lint, test
   - Frontend: lint, build
   - Flutter: analyze, test

2. **Code Review** by maintainers
   - At least 1 approval required
   - Address feedback promptly

3. **Approval & Merge**
   - Use **Squash and Merge**
   - Delete branch after merge

### Responding to Review Feedback

```bash
# Make changes based on feedback
git add .
git commit -m "fix: address review comments"
git push origin feature/your-feature

# PR automatically updates
```

---

## Code Standards

### Python (Backend)

```python
# Use Black for formatting
black webapp/backend/

# Use flake8 for linting
flake8 webapp/backend/

# Type hints required for public functions
def get_user(user_id: str) -> Optional[User]:
    """Fetch user by ID."""
    ...

# Docstrings for public APIs
def calculate_total(items: List[CartItem]) -> float:
    """
    Calculate total price for cart items.
    
    Args:
        items: List of cart items
        
    Returns:
        Total price including tax
    """
    ...
```

### JavaScript/React (Frontend)

```javascript
// Use ESLint + Prettier
npm run lint
npm run format

// Functional components with hooks
const MyComponent = () => {
  const [state, setState] = useState(null);
  
  useEffect(() => {
    // Side effects
  }, []);
  
  return <div>...</div>;
};

// PropTypes or TypeScript
MyComponent.propTypes = {
  userId: PropTypes.string.isRequired,
};
```

### Dart/Flutter (Mobile)

```dart
// Use flutter format
flutter format lib/

// Analyze before commit
flutter analyze

// Naming conventions
class UserProfile {}           // PascalCase for classes
void fetchUserData() {}        // camelCase for functions
final String userName = '';    // camelCase for variables
const double kPadding = 16.0;  // k prefix for constants
```

---

## Testing Requirements

### Backend Tests

```python
# pytest for unit tests
def test_calculate_total():
    items = [CartItem(price=10.0, quantity=2)]
    assert calculate_total(items) == 20.0

# Run tests
pytest webapp/backend/tests/
```

### Frontend Tests

```javascript
// Jest + React Testing Library
describe('CartItem', () => {
  it('displays correct quantity', () => {
    render(<CartItem quantity={3} />);
    expect(screen.getByText('3')).toBeInTheDocument();
  });
});

// Run tests
npm test
```

### Flutter Tests

```dart
// Widget tests
testWidgets('displays user name', (tester) async {
  await tester.pumpWidget(UserProfile(name: 'John'));
  expect(find.text('John'), findsOneWidget);
});

// Run tests
flutter test
```

### Test Coverage

- Aim for **>80% coverage** on critical paths
- Required for:
  - Authentication logic
  - Payment processing
  - Cart calculations
  - Data transformations

---

## Additional Guidelines

### Security

- **Never commit secrets** (.env files are gitignored)
- Use environment variables for API keys
- Validate all user inputs
- Sanitize database queries
- Use HTTPS in production

### Performance

- Optimize database queries (use indexes)
- Lazy load images and videos
- Minimize bundle size
- Use pagination for lists
- Cache where appropriate

### Accessibility

- Use semantic HTML
- Add ARIA labels
- Ensure keyboard navigation
- Test with screen readers
- Maintain color contrast ratios

### Documentation

- Update README.md if user-facing changes
- Add/update API documentation
- Comment complex logic
- Update DEPLOYMENT.md if infra changes

---

## Questions?

- **Slack**: #development channel
- **Email**: dev@yourdomain.com
- **Issues**: Open a GitHub Issue with `question` label

---

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.
